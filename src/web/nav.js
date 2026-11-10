// Navigation Ndoket — un seul handler : pas de double navigation
// + page transitions (fade-out → fade-in)
(function(){
  var transitioning = false;

  function go(p){
    if(transitioning) return;
    transitioning = true;
    setTimeout(function(){ transitioning = false; }, 600); // filet de sécurité
    var screen = document.querySelector('.screen');
    if(screen){
      screen.classList.add('page-exit');
      setTimeout(function(){
        window.location.href = p + '.html';
      }, 150);
    } else {
      window.location.href = p + '.html';
    }
  }

  // --- Retour : sur l'accueil on quitte l'application (sans jamais déconnecter) ---
  var ROOT_PAGES = ['index.html', 'login.html', 'accueil_client.html', 'accueil_prestataire.html'];

  function currentPage(){
    var p = (window.location.pathname || '').split('/').pop();
    return p || 'index.html';
  }

  function quitApp(){
    try{
      var App = null;
      if(window.Capacitor){
        if(window.Capacitor.Plugins && window.Capacitor.Plugins.App){ App = window.Capacitor.Plugins.App; }
        else if(typeof window.Capacitor.registerPlugin === 'function'){ App = window.Capacitor.registerPlugin('App'); }
      }
      if(App && App.minimizeApp){ App.minimizeApp(); return; }
    }catch(e){}
    try{ window.close(); }catch(e){}
  }

  function handleBack(){
    // Sur l'accueil (ou l'écran d'accueil) : quitter/minimiser l'app, la session reste active
    if(ROOT_PAGES.indexOf(currentPage()) > -1){ quitApp(); return; }
    if(window.history.length > 1){
      window.history.back();
    } else {
      // Pas d'historique : retour à l'accueil selon le rôle
      go(isPro() ? 'accueil_prestataire' : 'accueil_client');
    }
  }

  window.__ndoketBack = handleBack;
  window.__ndoketQuit = quitApp;
  window.__ndoketIsRoot = function(){ return ROOT_PAGES.indexOf(currentPage()) > -1; };

  function up(el, sel){
    if(el && el.closest){ return el.closest(sel); }
    while(el && el !== document.body){
      if(el.matches && el.matches(sel)){ return el; }
      el = el.parentNode;
    }
    return null;
  }

  function isPro(){
    return !!document.querySelector('[data-role="prestataire"]');
  }

  document.addEventListener('click', function(e){
    // 0) Fermer les toasts ouverts au clic
    var openToast = document.querySelector('.toast.show');
    if(openToast && !up(e.target, '.toast')){
      openToast.classList.remove('show');
    }

    // 1) data-nav explicite (priorité absolue)
    var el = up(e.target, '[data-nav]');
    if(el){
      var target = el.getAttribute('data-nav');
      if(target && target !== '#'){
        e.preventDefault();
        go(target);
      }
      return;
    }

    // 2) bouton retour
    el = up(e.target, '.back, .icon-btn.back');
    if(el){
      e.preventDefault();
      e.stopPropagation();
      handleBack();
      return;
    }

    // 3) onglets sans data-nav : on déduit du texte
    el = up(e.target, '.tabs .tab, .tabbar .tab');
    if(el){
      var txt = (el.textContent || '').trim().toLowerCase();
      var pro = isPro();
      if(txt.indexOf('accueil') > -1){ go(pro ? 'accueil_prestataire' : 'accueil_client'); }
      else if(txt.indexOf('service') > -1){ go(pro ? 'fixer_prix' : 'fiche_services'); }
      else if(txt.indexOf('avis') > -1){ go('fiche_avis'); }
      else if(txt.indexOf('propos') > -1){ go('fiche_apropos'); }
      else if(txt.indexOf('rdv') > -1){ go(pro ? 'accueil_prestataire' : 'mes_reservations'); }
      else if(txt.indexOf('profil') > -1){ go(pro ? 'profil_prestataire' : 'profil_client'); }
      else if(txt.indexOf('recherche') > -1){ go('recherche'); }
    }
  });

  // Toast helper global
  window.showToast = function(msg, duration){
    duration = duration || 2500;
    var t = document.querySelector('.toast');
    if(!t){
      t = document.createElement('div');
      t.className = 'toast';
      document.body.appendChild(t);
    }
    t.textContent = msg;
    t.classList.add('show');
    setTimeout(function(){ t.classList.remove('show'); }, duration);
  };

  // Ouvre une URL externe (Google Maps, WhatsApp, mailto…) dans le navigateur du téléphone
  window.openExternal = function(url){
    try{
      var App = null;
      if(window.Capacitor){
        if(window.Capacitor.Plugins && window.Capacitor.Plugins.App){ App = window.Capacitor.Plugins.App; }
        else if(typeof window.Capacitor.registerPlugin === 'function'){ App = window.Capacitor.registerPlugin('App'); }
      }
      if(App && App.openUrl){ App.openUrl({ url: url }); return; }
    }catch(e){}
    window.open(url, '_blank');
  };

  // --- Bouton retour Android + liens ndoket:// ---
  (function(){
    var App = null;
    try{
      if(window.Capacitor){
        if(window.Capacitor.Plugins && window.Capacitor.Plugins.App){
          App = window.Capacitor.Plugins.App;
        } else if(typeof window.Capacitor.registerPlugin === 'function'){
          App = window.Capacitor.registerPlugin('App');
        }
      }
    }catch(e){}
    if(!App || !App.addListener) return;
    try{
      App.addListener('backButton', function(data){
        // Sur l'accueil : quitter l'app (la session reste active)
        if(ROOT_PAGES.indexOf(currentPage()) > -1){ quitApp(); return; }
        var canGoBack = (data && typeof data.canGoBack === 'boolean') ? data.canGoBack : (window.history.length > 1);
        if(canGoBack){
          window.history.back();
        } else if(App.minimizeApp){
          App.minimizeApp();
        }
      });
      App.addListener('appUrlOpen', function(data){
        var u = (data && data.url) || '';
        var pm = u.match(/payment\/(success|cancel)\?ref=([A-Za-z0-9-]+)/);
        if(pm){
          if(window.ndoket){ window.ndoket.set('pending_ref', pm[2]); }
          setTimeout(function(){ window.location.href = 'paiement_statut.html'; }, 200);
          return;
        }
        var m = u.match(/prestataire\/([A-Za-z0-9-]+)/);
        if(m && window.ndoket){
          window.ndoket.setPrestataire(m[1]);
          setTimeout(function(){ window.location.href = 'fiche_services.html'; }, 200);
        }
      });
    }catch(e){}
  })();
})();