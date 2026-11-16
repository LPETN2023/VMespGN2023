/* site.js - comportements communs du site (menu, icônes, zoom, générateurs).
   Aucune dépendance. Fonctionne en file://. Ne pas ajouter de fetch / module / CDN. */
(function () {
  'use strict';

  /* ---------- Icônes SVG (jeu fermé) ---------- */
  var ICONES = {
    engrenage: '<circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 00.3 1.8l.1.1a2 2 0 11-2.8 2.8l-.1-.1a1.7 1.7 0 00-1.8-.3 1.7 1.7 0 00-1 1.5V21a2 2 0 11-4 0v-.1a1.7 1.7 0 00-1.1-1.5 1.7 1.7 0 00-1.8.3l-.1.1a2 2 0 11-2.8-2.8l.1-.1a1.7 1.7 0 00.3-1.8 1.7 1.7 0 00-1.5-1H3a2 2 0 110-4h.1a1.7 1.7 0 001.5-1.1 1.7 1.7 0 00-.3-1.8l-.1-.1a2 2 0 112.8-2.8l.1.1a1.7 1.7 0 001.8.3H9a1.7 1.7 0 001-1.5V3a2 2 0 114 0v.1a1.7 1.7 0 001 1.5 1.7 1.7 0 001.8-.3l.1-.1a2 2 0 112.8 2.8l-.1.1a1.7 1.7 0 00-.3 1.8V9a1.7 1.7 0 001.5 1H21a2 2 0 110 4h-.1a1.7 1.7 0 00-1.5 1z"/>',
    dossier: '<path d="M22 19a2 2 0 01-2 2H4a2 2 0 01-2-2V5a2 2 0 012-2h5l2 3h9a2 2 0 012 2z"/>',
    loupe: '<circle cx="11" cy="11" r="8"/><path d="M21 21l-4.35-4.35"/>',
    info: '<circle cx="12" cy="12" r="10"/><path d="M12 16v-4M12 8h.01"/>',
    video: '<rect x="1" y="5" width="15" height="14" rx="2"/><path d="M23 7l-7 5 7 5z"/>',
    terminal: '<path d="M4 17l6-6-6-6M12 19h8"/>',
    cle: '<path d="M21 2l-2 2m-7.61 7.61a5.5 5.5 0 11-7.778 7.778 5.5 5.5 0 017.777-7.777zm0 0L15.5 7.5m0 0l3 3L22 7l-3-3m-3.5 3.5L19 4"/>',
    telephone: '<path d="M22 16.92v3a2 2 0 01-2.18 2 19.79 19.79 0 01-8.63-3.07 19.5 19.5 0 01-6-6 19.79 19.79 0 01-3.07-8.67A2 2 0 014.11 2h3a2 2 0 012 1.72 12.84 12.84 0 00.7 2.81 2 2 0 01-.45 2.11L8.09 9.91a16 16 0 006 6l1.27-1.27a2 2 0 012.11-.45 12.84 12.84 0 002.81.7A2 2 0 0122 16.92z"/>',
    mail: '<path d="M4 4h16a2 2 0 012 2v12a2 2 0 01-2 2H4a2 2 0 01-2-2V6a2 2 0 012-2z"/><path d="M22 6l-10 7L2 6"/>',
    globe: '<circle cx="12" cy="12" r="10"/><path d="M2 12h20"/><path d="M12 2a15.3 15.3 0 014 10 15.3 15.3 0 01-4 10 15.3 15.3 0 01-4-10 15.3 15.3 0 014-10z"/>',
    utilisateur: '<path d="M20 21v-2a4 4 0 00-4-4H8a4 4 0 00-4 4v2"/><circle cx="12" cy="7" r="4"/>',
    alerte: '<path d="M10.29 3.86L1.82 18a2 2 0 001.71 3h16.94a2 2 0 001.71-3L13.71 3.86a2 2 0 00-3.42 0z"/><path d="M12 9v4M12 17h.01"/>'
  };

  function svgIcone(nom) {
    var corps = ICONES[nom];
    if (!corps) { return ''; }
    return '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" focusable="false">' + corps + '</svg>';
  }

  function initialiserIcones(racine) {
    var els = (racine || document).querySelectorAll('.icone[data-icone]');
    for (var i = 0; i < els.length; i++) {
      els[i].innerHTML = svgIcone(els[i].getAttribute('data-icone'));
      els[i].setAttribute('aria-hidden', 'true');
    }
  }

  /* ---------- Génération de commandes (logique pure, testable) ---------- */
  function normaliserChiffres(v) {
    return String(v).replace(/\D/g, '').replace(/^0+/, '');
  }

  /* Retourne la commande, ou null si une valeur est vide (chaîne vide stricte, sans trim)
     ou vide après formatage. formats : {champ: 'chiffres'} (facultatif).
     options : {nom: texte} pour les cases à cocher d'option (texte vide si décochée ; jamais en erreur). */
  function genererCommande(modele, valeurs, formats, options) {
    valeurs = valeurs || {};
    formats = formats || {};
    options = options || {};
    var finales = {};
    Object.keys(options).forEach(function (n) { finales[n] = String(options[n] == null ? '' : options[n]); });
    var noms = Object.keys(valeurs);
    for (var i = 0; i < noms.length; i++) {
      var v = String(valeurs[noms[i]] == null ? '' : valeurs[noms[i]]);
      if (v === '') { return null; }
      if (formats[noms[i]] === 'chiffres') {
        v = normaliserChiffres(v);
        if (v === '') { return null; }
      }
      finales[noms[i]] = v;
    }
    return String(modele).replace(/\{([^{}]+)\}/g, function (tout, nom) {
      return Object.prototype.hasOwnProperty.call(finales, nom) ? finales[nom] : tout;
    });
  }

  /* ---------- Presse-papier ---------- */
  function copierTexte(texte) {
    return new Promise(function (resolve, reject) {
      function repli() {
        try {
          var actif = document.activeElement;
          var debut = null, fin = null;
          try { debut = actif.selectionStart; fin = actif.selectionEnd; } catch (e0) { /* pas un champ texte */ }
          var ta = document.createElement('textarea');
          ta.value = texte;
          ta.setAttribute('readonly', '');
          ta.style.cssText = 'position:fixed;top:0;left:0;opacity:0;';
          document.body.appendChild(ta);
          ta.select();
          ta.setSelectionRange(0, texte.length);
          var ok = document.execCommand('copy');
          document.body.removeChild(ta);
          if (actif && actif.focus) {
            actif.focus();
            try { if (debut !== null) { actif.setSelectionRange(debut, fin); } } catch (e1) { /* ignoré */ }
          }
          if (ok) { resolve(); } else { reject(new Error('execCommand')); }
        } catch (e) { reject(e); }
      }
      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(texte).then(resolve, repli);
      } else {
        repli();
      }
    });
  }

  /* ---------- Générateurs ---------- */
  function initialiserGenerateur(gen) {
    if (gen.getAttribute('data-initialise')) { return; }
    gen.setAttribute('data-initialise', '1');
    var modele = gen.getAttribute('data-modele') || '';
    var messageErreur = gen.getAttribute('data-erreur') || 'Veuillez renseigner tous les champs.';
    var champs = gen.querySelectorAll('[data-champ]');
    var cases = gen.querySelectorAll('input[type="checkbox"][data-option]');
    var bouton = gen.querySelector('button');
    var sortie = gen.querySelector('output');
    var statut = gen.querySelector('.statut');
    if (!sortie) { sortie = document.createElement('output'); gen.appendChild(sortie); }
    if (!statut) { statut = document.createElement('span'); statut.className = 'statut'; gen.appendChild(statut); }
    statut.setAttribute('role', 'status');
    statut.setAttribute('aria-live', 'polite');
    var minuterie = null;

    function afficherStatut(texte, erreur) {
      statut.textContent = texte;
      statut.className = 'statut' + (erreur ? ' erreur' : '');
      clearTimeout(minuterie);
      if (texte && !erreur) {
        minuterie = setTimeout(function () { statut.textContent = ''; }, 2000);
      }
    }

    function lancer() {
      var valeurs = {}, formats = {};
      for (var i = 0; i < champs.length; i++) {
        var nom = champs[i].getAttribute('data-champ');
        valeurs[nom] = champs[i].value;
        var f = champs[i].getAttribute('data-format');
        if (f) { formats[nom] = f; }
      }
      var options = {};
      for (var k = 0; k < cases.length; k++) {
        options[cases[k].getAttribute('data-option')] = cases[k].checked ? (cases[k].getAttribute('data-valeur') || '') : '';
      }
      var commande = genererCommande(modele, valeurs, formats, options);
      if (commande === null) {
        sortie.textContent = messageErreur;
        sortie.className = 'erreur';
        afficherStatut('', false);
        return;
      }
      sortie.textContent = commande;
      sortie.className = '';
      copierTexte(commande).then(function () {
        afficherStatut('Copié !', false);
      }, function () {
        afficherStatut('Copie automatique impossible : sélectionnez le texte.', true);
      });
    }

    if (bouton) { bouton.addEventListener('click', lancer); }
    for (var j = 0; j < champs.length; j++) {
      champs[j].addEventListener('keydown', function (e) {
        if (e.key === 'Enter') { e.preventDefault(); lancer(); }
      });
    }
  }

  function initialiserGenerateurs(racine) {
    var gens = (racine || document).querySelectorAll('.generateur');
    for (var i = 0; i < gens.length; i++) { initialiserGenerateur(gens[i]); }
  }

  /* ---------- Lightbox ---------- */
  var lightbox = null, dernierFocus = null;

  function fermerLightbox() {
    if (!lightbox) { return; }
    lightbox.parentNode.removeChild(lightbox);
    lightbox = null;
    document.removeEventListener('keydown', toucheLightbox, true);
    if (dernierFocus && dernierFocus.focus) { dernierFocus.focus(); }
  }

  function toucheLightbox(e) {
    if (e.key === 'Escape') { e.preventDefault(); fermerLightbox(); }
    else if (e.key === 'Tab') { e.preventDefault(); }
  }

  function ouvrirLightbox(img) {
    if (lightbox) { return; }
    dernierFocus = document.activeElement;
    lightbox = document.createElement('div');
    lightbox.className = 'lightbox';
    lightbox.setAttribute('role', 'dialog');
    lightbox.setAttribute('aria-modal', 'true');
    lightbox.setAttribute('aria-label', img.getAttribute('alt') || 'Image agrandie');
    var grande = document.createElement('img');
    grande.src = img.currentSrc || img.src;
    grande.alt = img.getAttribute('alt') || '';
    var fermer = document.createElement('button');
    fermer.type = 'button';
    fermer.className = 'lightbox-fermer';
    fermer.setAttribute('aria-label', 'Fermer');
    fermer.innerHTML = '&times;';
    lightbox.appendChild(grande);
    lightbox.appendChild(fermer);
    lightbox.addEventListener('click', fermerLightbox);
    document.body.appendChild(lightbox);
    document.addEventListener('keydown', toucheLightbox, true);
    fermer.focus();
  }

  function initialiserZoom() {
    function cible(e) {
      var t = e.target;
      return t && t.tagName === 'IMG' && t.classList.contains('zoom') ? t : null;
    }
    document.addEventListener('click', function (e) {
      var img = cible(e);
      if (img) { ouvrirLightbox(img); }
    });
    document.addEventListener('keydown', function (e) {
      if ((e.key === 'Enter' || e.key === ' ') && !lightbox) {
        var img = cible(e);
        if (img) { e.preventDefault(); ouvrirLightbox(img); }
      }
    });
    var imgs = document.querySelectorAll('img.zoom');
    for (var i = 0; i < imgs.length; i++) {
      imgs[i].setAttribute('tabindex', '0');
      imgs[i].setAttribute('role', 'button');
      if (!imgs[i].getAttribute('title')) { imgs[i].setAttribute('title', 'Cliquer pour agrandir'); }
    }
  }

  /* ---------- En-tête et menu ---------- */
  function pageCourante() {
    var data = document.body && document.body.getAttribute('data-page');
    if (data) { return data; }
    var chemin = (location.pathname || '').split('/').pop();
    try { chemin = decodeURIComponent(chemin); } catch (e) { /* garde la valeur brute */ }
    return chemin || 'index.html';
  }

  function menuValide(m) {
    if (!Array.isArray(m) || m.length === 0) { return false; }
    for (var i = 0; i < m.length; i++) {
      var o = m[i];
      if (!o || typeof o.titre !== 'string') { return false; }
      if (typeof o.lien === 'string') { continue; }
      if (!Array.isArray(o.sous)) { return false; }
      for (var j = 0; j < o.sous.length; j++) {
        if (!o.sous[j] || typeof o.sous[j].titre !== 'string' || typeof o.sous[j].lien !== 'string') { return false; }
      }
    }
    return true;
  }

  function lienSur(href) {
    return /^\s*(javascript|data|vbscript):/i.test(href) ? '#' : href;
  }

  function el(tag, classe, texte) {
    var e = document.createElement(tag);
    if (classe) { e.className = classe; }
    if (texte != null) { e.textContent = texte; }
    return e;
  }

  function construireEntete() {
    var entete = document.getElementById('entete');
    if (!entete) { return; }
    entete.textContent = '';
    var courante = pageCourante();
    var menu = window.MENU;
    var valide = menuValide(menu);
    if (!valide) {
      if (window.console) { console.error('site.js : window.MENU absent ou invalide (voir menu.js). En-tête de secours affiché.'); }
      menu = [{ titre: 'Accueil', lien: 'index.html' }];
    }

    var interieur = el('div', 'entete-int');
    var logo = el('a', 'logo');
    logo.href = 'index.html';
    var img = document.createElement('img');
    img.src = 'images/logo-saesp.png';
    img.alt = 'Accueil';
    img.width = 100; img.height = 100;
    logo.appendChild(img);
    interieur.appendChild(logo);

    var burger = el('button', 'burger');
    burger.type = 'button';
    burger.setAttribute('aria-label', 'Menu');
    burger.setAttribute('aria-expanded', 'false');
    burger.setAttribute('aria-controls', 'nav-principale');
    burger.innerHTML = '<span></span><span></span><span></span>';
    interieur.appendChild(burger);

    var nav = el('nav');
    nav.id = 'nav-principale';
    nav.setAttribute('aria-label', 'Navigation principale');
    var ul = el('ul', 'nav-liste');
    var deroulants = [];

    menu.forEach(function (item) {
      var li = el('li');
      if (item.sous) {
        li.className = 'deroulant';
        var b = el('button', 'onglet');
        b.type = 'button';
        b.setAttribute('aria-haspopup', 'true');
        b.setAttribute('aria-expanded', 'false');
        b.appendChild(document.createTextNode(item.titre));
        b.appendChild(el('span', 'caret'));
        var sub = el('ul', 'sous-menu');
        var actifSous = false;
        item.sous.forEach(function (s) {
          var sli = el('li');
          var a = el('a', null, s.titre);
          a.href = lienSur(s.lien);
          if (s.lien === courante) { a.className = 'actif'; a.setAttribute('aria-current', 'page'); actifSous = true; }
          sli.appendChild(a);
          sub.appendChild(sli);
        });
        if (actifSous) { b.className += ' actif'; }
        li.appendChild(b);
        li.appendChild(sub);
        deroulants.push(li);
      } else {
        var a2 = el('a', 'onglet', item.titre);
        a2.href = lienSur(item.lien);
        if (item.lien === courante) { a2.className += ' actif'; a2.setAttribute('aria-current', 'page'); }
        li.appendChild(a2);
      }
      ul.appendChild(li);
    });
    nav.appendChild(ul);
    interieur.appendChild(nav);
    entete.appendChild(interieur);

    /* Burger */
    burger.addEventListener('click', function () {
      var ouvert = entete.classList.toggle('menu-ouvert');
      burger.setAttribute('aria-expanded', ouvert ? 'true' : 'false');
    });

    /* Menus déroulants : survol (écran large), clic, clavier */
    var large = function () { return window.innerWidth >= 800; };

    function ouvrir(li, survol) {
      fermerTous(li);
      li.classList.add('ouvert');
      li.setAttribute('data-survol', survol ? '1' : '');
      li.firstChild.setAttribute('aria-expanded', 'true');
    }
    function fermer(li) {
      li.classList.remove('ouvert');
      li.setAttribute('data-survol', '');
      li.firstChild.setAttribute('aria-expanded', 'false');
    }
    function fermerTous(sauf) {
      deroulants.forEach(function (d) { if (d !== sauf) { fermer(d); } });
    }

    deroulants.forEach(function (li) {
      var bouton = li.firstChild;
      var minuterie = null;
      li.addEventListener('mouseenter', function () {
        if (!large()) { return; }
        clearTimeout(minuterie);
        if (!li.classList.contains('ouvert')) { ouvrir(li, true); }
      });
      li.addEventListener('mouseleave', function () {
        if (!large()) { return; }
        if (li.getAttribute('data-survol') === '1') {
          minuterie = setTimeout(function () { fermer(li); }, 180);
        }
      });
      bouton.addEventListener('click', function () {
        if (li.classList.contains('ouvert')) {
          if (li.getAttribute('data-survol') === '1') { li.setAttribute('data-survol', ''); }
          else { fermer(li); }
        } else {
          ouvrir(li, false);
        }
      });
      li.addEventListener('focusout', function (e) {
        if (li.classList.contains('ouvert') && li.getAttribute('data-survol') !== '1' && !(e.relatedTarget && li.contains(e.relatedTarget))) { fermer(li); }
      });
      li.addEventListener('keydown', function (e) {
        var liens = li.querySelectorAll('.sous-menu a');
        var pos = Array.prototype.indexOf.call(liens, document.activeElement);
        if (e.key === 'Escape') {
          if (li.classList.contains('ouvert')) { fermer(li); bouton.focus(); e.stopPropagation(); }
        } else if (e.key === 'ArrowDown') {
          e.preventDefault();
          if (!li.classList.contains('ouvert')) { ouvrir(li, false); }
          if (liens.length) { liens[Math.min(pos + 1, liens.length - 1)].focus(); }
        } else if (e.key === 'ArrowUp') {
          e.preventDefault();
          if (pos > 0) { liens[pos - 1].focus(); } else { bouton.focus(); }
        }
      });
    });

    document.addEventListener('click', function (e) {
      if (!entete.contains(e.target)) { fermerTous(null); }
    });
    window.addEventListener('resize', function () {
      if (large()) { entete.classList.remove('menu-ouvert'); burger.setAttribute('aria-expanded', 'false'); }
    });
  }

  function construirePied() {
    var pied = document.getElementById('pied');
    if (pied && !pied.firstChild) {
      pied.textContent = "Système d'assistance à l'Enquêteur Sous Pseudonyme";
    }
  }

  /* ---------- Démarrage ---------- */
  function demarrer() {
    construireEntete();
    construirePied();
    initialiserIcones();
    initialiserGenerateurs();
    initialiserZoom();
  }

  window.VMESP = {
    genererCommande: genererCommande,
    normaliserChiffres: normaliserChiffres,
    initialiserIcones: initialiserIcones,
    initialiserGenerateurs: initialiserGenerateurs,
    icones: Object.keys(ICONES)
  };

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', demarrer);
  } else {
    demarrer();
  }
})();
