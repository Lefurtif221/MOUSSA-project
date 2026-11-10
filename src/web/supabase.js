// Ndoket — Configuration & helpers Supabase
const SUPABASE_URL = 'https://otmhstzhucydejvblmgo.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im90bWhzdHpodWN5ZGVqdmJsbWdvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODYxNzk5ODgsImV4cCI6MjEwMTc1NTk4OH0.CNoTZxuDhGCvPhGY0U7cNPO7VUYvmKhubWRI_oQE1NQ';

// Domaine public hébergé (pages de partage / liens d'email hors app)
const APP_HOST = 'https://lefurtif221.github.io/ndoket-site';

// Anti-XSS : échappe un texte avant insertion dans innerHTML
function esc(s){
  return String(s == null ? '' : s)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}
// Anti-XSS : échappe une URL (rejette javascript:, data:…html, etc.)
function escUrl(u){
  var s = String(u == null ? '' : u).trim();
  if(/^(javascript|data|vbscript):/i.test(s)) return '';
  return esc(s);
}

// Sessions souvenir (côté client webview)
function saveSession(session){ localStorage.setItem('ndoket_session', JSON.stringify(session)); }
function loadSession(){
  try { return JSON.parse(localStorage.getItem('ndoket_session') || 'null'); }
  catch(e){ return null; }
}
function clearSession(){ localStorage.removeItem('ndoket_session'); }
// Utilisateur de la session locale (synchrone) — null si non connecté
function sessionUser(){
  const s = loadSession();
  return (s && s.user) || null;
}
// Renouvelle le jeton d'accès : la session reste active tant que l'utilisateur
// ne se déconnecte pas manuellement (fermer l'application ne déconnecte pas)
var _refreshPromise = null;
async function refreshSession(){
  // Un seul renouvellement à la fois (le jeton de rafraîchissement tourne)
  if(_refreshPromise) return _refreshPromise;
  _refreshPromise = (async () => {
    const s = loadSession();
    if(!s || !s.refresh_token) return false;
    try{
      const res = await fetch(SUPABASE_URL + '/auth/v1/token?grant_type=refresh_token', {
        method: 'POST',
        headers: { 'apikey': SUPABASE_ANON_KEY, 'Content-Type': 'application/json' },
        body: JSON.stringify({ refresh_token: s.refresh_token })
      });
      if(!res.ok) return false;
      const j = await res.json();
      if(!j.user && s.user) j.user = s.user;
      saveSession(j);
      return true;
    }catch(e){ return false; }
  })();
  try{
    return await _refreshPromise;
  } finally {
    _refreshPromise = null;
  }
}
async function ensureFreshSession(){
  const s = loadSession();
  if(!s) return;
  if(s.expires_at && (s.expires_at * 1000) < (Date.now() + 90000)){
    await refreshSession();
  }
}

// Petit client fetch maison (pas de dépendance CDN)
const supabase = (() => {
  function bearer(){ const s = loadSession(); return s ? s.access_token : SUPABASE_ANON_KEY; }
  function headers(prefer){
    const h = {
      'apikey': SUPABASE_ANON_KEY,
      'Authorization': 'Bearer ' + bearer(),
      'Content-Type': 'application/json'
    };
    if(prefer) h['Prefer'] = prefer;
    return h;
  }
  async function request(method, path, body, prefer){
    // Rafraîchir le jeton avant expiration (ou après coup, si 401)
    await ensureFreshSession();
    const doFetch = () => {
      const opt = { method, headers: headers(prefer) };
      if(body !== undefined){ opt.body = JSON.stringify(body); }
      return fetch(SUPABASE_URL + path, opt);
    };
    let res = await doFetch();
    if(res.status === 401 && loadSession()){
      const renewed = await refreshSession();
      if(renewed){ res = await doFetch(); }
    }
    if(res.status === 204) return null;
    const json = await res.json().catch(() => null);
    if(!res.ok){ throw new Error((json && (json.message || json.error_description || json.msg)) || ('Erreur ' + res.status)); }
    return json;
  }

  return {
    // ---------- AUTH ----------
    signUp(email, password){ return request('POST', '/auth/v1/signup', { email, password }); },
    signIn(email, password){ return request('POST', '/auth/v1/token?grant_type=password', { email, password }); },
    // redirect_to doit être une page hébergée (dans la WebView l'origin est localhost)
    resetPassword(email){ return request('POST', '/auth/v1/recover', { email, gotrue_meta_security: { redirect_to: APP_HOST + '/reset_password.html' } }); },
    signInWithGoogle(idToken){ return request('POST', '/auth/v1/token?grant_type=id_token', { provider: 'google', id_token: idToken }); },
    signOut(){
      const s = loadSession();
      // Nettoyer TOUTES les données locales de la session (pid, espace, booking…)
      clearSession();
      try {
        ['prestataire_id','space','booking','frais','pending_ref','genre','pro_email'].forEach(function(k){
          localStorage.removeItem('ndoket_' + k);
        });
      } catch(e){}
      if(!s) return Promise.resolve();
      return fetch(SUPABASE_URL + '/auth/v1/logout', { method: 'POST', headers: { apikey: SUPABASE_ANON_KEY, Authorization: 'Bearer ' + s.access_token } })
        .then(function(){});
    },
    currentUser(){ return request('GET', '/auth/v1/user'); },

    // ---------- BASE DE DONNEES ----------
    select(table, query){
      let q = '/rest/v1/' + table + '?select=*';
      if(query){
        for(const k in query){
          if(query[k] !== undefined && query[k] !== null){ q += '&' + k + '=' + encodeURIComponent(query[k]); }
        }
      }
      return request('GET', q);
    },
    insert(table, rows){ return request('POST', '/rest/v1/' + table, rows, 'return=representation'); },
    update(table, patch, matchCol, matchVal){
      return request('PATCH', '/rest/v1/' + table + '?' + matchCol + '=eq.' + encodeURIComponent(matchVal), patch, 'return=representation');
    },
    delete(table, matchCol, matchVal){
      return request('DELETE', '/rest/v1/' + table + '?' + matchCol + '=eq.' + encodeURIComponent(matchVal));
    },
    rpc(fn, body){ return request('POST', '/rest/v1/rpc/' + fn, body || {}); },

    // ---------- STORAGE (upload photo) ----------
    async uploadPhoto(file, path){
      const s = loadSession();
      if(!s) throw new Error('Non connecté');
      const res = await fetch(SUPABASE_URL + '/storage/v1/object/ndoket-photos/' + path, {
        method: 'POST',
        headers: {
          'apikey': SUPABASE_ANON_KEY,
          'Authorization': 'Bearer ' + s.access_token,
          'Content-Type': file.type || 'image/jpeg'
        },
        body: file
      });
      if(!res.ok){
        const j = await res.json().catch(()=>null);
        throw new Error((j && (j.message||j.error)) || 'Upload échoué (' + res.status + ')');
      }
      return SUPABASE_URL + '/storage/v1/object/public/ndoket-photos/' + path;
    }
  };
})();

// ---------- État partagé du parcours de réservation ----------
const ndoket = {
  set(key, val){ localStorage.setItem('ndoket_' + key, JSON.stringify(val)); },
  get(key, def){
    try {
      const v = localStorage.getItem('ndoket_' + key);
      return v === null ? (def === undefined ? null : def) : JSON.parse(v);
    } catch(e){ return def === undefined ? null : def; }
  },
  // Prestataire en cours de consultation
  prestataireId(){ return this.get('prestataire_id'); },
  setPrestataire(id){ this.set('prestataire_id', id); },
  // Sélection en cours de réservation
  setBooking(b){ this.set('booking', Object.assign({}, this.get('booking', {}), b)); },
  getBooking(){ return this.get('booking', {}); },
  clearBooking(){ localStorage.removeItem('ndoket_booking'); }
};

// ---------- Notifications simplifiées (sonderie) ----------
// ---------- Notifications push (FCM via Capacitor) ----------
var _pushToken = null;

// Demander l'abonnement aux notifications push
async function initPushNotifications(){
  try {
    if(!window.Capacitor || !window.Capacitor.Plugins || !window.Capacitor.Plugins.PushNotifications){
      // Pas de plugin (dev web) → fallback polling
      startRdvPolling();
      return;
    }
    const Push = window.Capacitor.Plugins.PushNotifications;

    // Demander la permission
    let perm = await Push.checkPermissions();
    if(perm.receive !== 'granted'){
      perm = await Push.requestPermissions();
    }
    if(perm.receive !== 'granted'){
      startRdvPolling();
      return;
    }

    // Configurer et s'abonner
    await Push.configure();
    const result = await Push.register();
    if(result && result.pushToken && result.pushToken.value){
      _pushToken = result.pushToken.value;
      // Enregistrer le jeton en base
      supabase.rpc('save_push_token', { p_token: _pushToken }).catch(function(){});
    }

    // Écouter les notifications reçues
    Push.addListener('pushNotificationReceived', function(notification){
      var title = (notification && notification.title) || 'Ndoket';
      var body = (notification && notification.body) || '';
      if(window.showToast){ showToast(title + ' : ' + body, 5000); }
    });

    // Écouter les clics sur les notifications
    Push.addListener('pushNotificationActionPerformed', function(action){
      var data = (action && action.notification && action.notification.data) || {};
      if(data.page){
        setTimeout(function(){ window.location.href = data.page; }, 300);
      }
    });

  } catch(e){
    console.error('Push init error:', e);
    // Fallback : polling des nouveaux RDV
    startRdvPolling();
  }
}

// Envoyer une notification (appelé depuis les pages)
function sendPush(to, prestataireId, userId, title, body, data){
  var sess = loadSession();
  if(!sess) return;
  fetch(SUPABASE_URL + '/functions/v1/notify', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'apikey': SUPABASE_ANON_KEY,
      'Authorization': 'Bearer ' + sess.access_token
    },
    body: JSON.stringify({
      to: to,
      prestataire_id: prestataireId || undefined,
      user_id: userId || undefined,
      title: title,
      body: body,
      data: data || {}
    })
  }).catch(function(){});
}

// Vérifie périodiquement les nouveaux RDV (fallback sans push)
var _ndoketNotifTimer = null;
var _ndoketLastRdvCount = null;
function startRdvPolling(){
  if(_ndoketNotifTimer) return;
  var me = sessionUser();
  if(!me) return;
  // Fonctionne côté presta uniquement
  function poll(){
    var u = sessionUser();
    if(!u){ stopRdvPolling(); return; }
    var pid = ndoket.prestataireId();
    if(!pid){ return; }
    supabase.select('reservations', { prestataire_id: 'eq.' + pid, statut: 'eq.confirme' }).then(function(rows){
      var count = (rows || []).length;
      if(_ndoketLastRdvCount !== null && count > _ndoketLastRdvCount){
        showToast('📋 Nouveau rendez-vous ! (' + count + ' en attente)');
      }
      _ndoketLastRdvCount = count;
    }).catch(function(){});
  }
  _ndoketNotifTimer = setInterval(poll, 30000); // toutes les 30s
  poll(); // premier check immédiat
}
function stopRdvPolling(){
  if(_ndoketNotifTimer){ clearInterval(_ndoketNotifTimer); _ndoketNotifTimer = null; }
  _ndoketLastRdvCount = null;
}

const GOOGLE_WEB_CLIENT_ID = '720315708499-gqf8foo1e828iuvmiq3acenrpujital6.apps.googleusercontent.com';

async function signInWithGoogle(){
  try {
    // Sur Android natif via Capacitor
    if(window.Capacitor && window.Capacitor.Plugins && window.Capacitor.Plugins.GoogleAuth){
      const GA = window.Capacitor.Plugins.GoogleAuth;
      await GA.initialize({
        clientId: GOOGLE_WEB_CLIENT_ID,
        scopes: ['profile', 'email'],
        grantOfflineAccess: false
      });
      // Forcer la sélection du compte (sinon Google reprend le dernier)
      await GA.signOut().catch(function(){});
      const googleUser = await GA.signIn();
      const idToken = (googleUser && googleUser.authentication && googleUser.authentication.idToken)
        || (googleUser && googleUser.idToken)
        || (googleUser && googleUser.authenticationIdToken)
        || null;
      if(!idToken){
        var keys = [];
        try { for(var k in googleUser){ keys.push(k + ':' + typeof googleUser[k]); } } catch(e){}
        var authKeys = [];
        try { if(googleUser && googleUser.authentication){ for(var k2 in googleUser.authentication){ authKeys.push(k2 + ':' + typeof googleUser.authentication[k2]); } } } catch(e){}
        throw new Error('Pas de idToken. top=[' + keys.join(',') + '] auth=[' + authKeys.join(',') + ']');
      }
      const session = await supabase.signInWithGoogle(idToken);
      saveSession(session);
      return session;
    }
    // Fallback : import dynamique (pour dev web)
    const { GoogleAuth } = await import('@codetrix-studio/capacitor-google-auth');
    await GoogleAuth.initialize({
      clientId: GOOGLE_WEB_CLIENT_ID,
      scopes: ['profile', 'email'],
      grantOfflineAccess: false
    });
    await GoogleAuth.signOut().catch(function(){});
    const googleUser = await GoogleAuth.signIn();
    const idToken = googleUser.authentication.idToken;
    const session = await supabase.signInWithGoogle(idToken);
    saveSession(session);
    return session;
  } catch(e){
    console.error('Google Sign-In error:', e);
    throw new Error('Google Sign-In échoué: ' + (e.message || e.toString()));
  }
}

// Position GPS de l'utilisateur (promesse)
function getMyPosition(timeout){
  return new Promise(function(resolve, reject){
    if(!navigator.geolocation){ reject({ code: 0, message: 'GPS non disponible' }); return; }
    navigator.geolocation.getCurrentPosition(function(pos){
      resolve({ latitude: pos.coords.latitude, longitude: pos.coords.longitude });
    }, function(err){ reject(err); }, {
      enableHighAccuracy: true,
      timeout: timeout || 12000,
      maximumAge: 30000
    });
  });
}

// Adresse lisible depuis des coordonnées (remplit le champ automatiquement)
function geoReverse(lat, lng){
  function shortParts(display_name){
    var parts = (display_name || '').split(',').map(function(s){ return s.trim(); });
    return parts.slice(0, 3).join(', ');
  }
  return fetch('https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=' + lat + '&lon=' + lng + '&accept-language=fr&zoom=16')
    .then(function(r){ return r.json(); })
    .then(function(j){
      if(!j || !j.display_name) throw new Error('no addr');
      return shortParts(j.display_name);
    })
    .catch(function(){
      // Secours : BigDataCloud (gratuit, sans clé)
      return fetch('https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=' + lat + '&longitude=' + lng + '&localityLanguage=fr')
        .then(function(r){ return r.json(); })
        .then(function(j){
          var bits = [j.city || j.locality || '', j.principalSubdivision || '', j.countryName || '']
            .map(function(s){ return (s || '').trim(); })
            .filter(function(s){ return !!s; });
          if(!bits.length) throw new Error('no addr');
          return bits.join(', ');
        });
    });
}

// Suggestions d'adresse pendant la frappe (choisir = remplir + position)
function attachAddressAutocomplete(input, onPick){
  var wrap = input.parentNode;
  try{
    if(wrap && window.getComputedStyle(wrap).position === 'static'){ wrap.style.position = 'relative'; }
  }catch(e){}
  var box = document.createElement('div');
  box.style.cssText = 'position:absolute;left:0;right:0;top:100%;z-index:40;background:#fff;border:2px solid #E5EEF1;border-radius:12px;margin-top:4px;box-shadow:0 12px 30px -12px rgba(31,42,51,.25);display:none;max-height:220px;overflow-y:auto;';
  if(wrap){ wrap.appendChild(box); }
  var timer = null;
  function hide(){ box.style.display = 'none'; box.innerHTML = ''; }
  input.addEventListener('input', function(){
    var q = input.value.trim();
    clearTimeout(timer);
    if(q.length < 3){ hide(); return; }
    timer = setTimeout(function(){
      fetch('https://nominatim.openstreetmap.org/search?format=jsonv2&accept-language=fr&countrycodes=sn&limit=5&q=' + encodeURIComponent(q))
        .then(function(r){ return r.json(); })
        .then(function(arr){
          if(!arr || !arr.length || document.activeElement !== input){ hide(); return; }
          box.innerHTML = '';
          arr.forEach(function(it){
            var parts = (it.display_name || '').split(',').map(function(s){ return s.trim(); });
            var label = parts.slice(0, 3).join(', ');
            var d = document.createElement('div');
            d.style.cssText = 'padding:11px 13px;font-size:12.5px;font-weight:600;color:#1F2A33;cursor:pointer;border-bottom:1px solid #F0F4F5;font-family:Inter,sans-serif;';
            d.textContent = label;
            d.addEventListener('mousedown', function(e){
              e.preventDefault();
              input.value = label;
              hide();
              if(onPick){ onPick({ latitude: parseFloat(it.lat), longitude: parseFloat(it.lon) }); }
            });
            box.appendChild(d);
          });
          box.style.display = 'block';
        }).catch(function(){});
    }, 450);
  });
  document.addEventListener('click', function(e){
    if(e.target !== input && !box.contains(e.target)){ hide(); }
  });
}
function autoRouteHome(){
  var u = sessionUser();
  if(!u) return false;
  // Initialiser les notifications push en arrière-plan
  initPushNotifications();
  function space(isPro){
    localStorage.setItem('ndoket_space', isPro ? 'pro' : 'client');
  }
  function fallback(){
    // Hors-ligne ou erreur : on rouvre le dernier espace choisi, jamais la page de connexion
    var s = localStorage.getItem('ndoket_space');
    if(s === 'pro'){ location.href = 'accueil_prestataire.html'; }
    else if(s === 'client'){ location.href = 'accueil_client.html'; }
  }
  supabase.select('profils', { id: 'eq.' + u.id }).then(function(rows){
    var p = rows && rows[0];
    if(!p){
      // Compte créé mais profil non complété : on termine l'inscription
      location.href = 'inscription_profil.html';
      return;
    }
    var isPro = p.role === 'prestataire' || !!p.prestataire_id;
    if(isPro && p.prestataire_id){
      ndoket.setPrestataire(p.prestataire_id);
      space(true);
      location.href = 'accueil_prestataire.html';
    } else if(isPro){
      location.href = 'inscription_pro.html';
    } else {
      ndoket.setPrestataire(p.prestataire_id || null);
      space(false);
      location.href = 'accueil_client.html';
    }
  }).catch(fallback);
  return true;
}