-- Ndoket — Photo de référence du modèle souhaité (commande)
-- La cliente peut joindre une photo pendant la commande (personnalisation) ;
-- elle est visible par la prestataire et la cliente dans le détail du RDV.
-- À exécuter dans l'éditeur SQL Supabase.

alter table public.reservations add column if not exists photo_reference text;
