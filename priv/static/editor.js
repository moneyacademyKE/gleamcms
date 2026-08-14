(function() {
  var names = [];
  var app = document.getElementById('app');
  if (app && app.dataset.themes) {
    try { names = JSON.parse(app.dataset.themes); } catch(e) { names = []; }
  }
  var picker = document.getElementById('theme-picker');
  if (picker) {
    picker.innerHTML = '';
    names.forEach(function(n) {
      var o = document.createElement('option');
      o.value = n; o.textContent = n;
      picker.appendChild(o);
    });
    picker.addEventListener('change', function() {
      document.documentElement.setAttribute('data-theme', picker.value);
    });
  }

  var btn = document.getElementById('btn-generate');
  var link = document.getElementById('generated-link');
  var slugField = document.getElementById('field-slug');
  if (btn) {
    btn.addEventListener('click', async function() {
      btn.disabled = true;
      btn.textContent = '⏳ Generating…';
      try {
        var theme = picker ? picker.value : 'Default Dark';
        var url = '/api/generate?theme=' + encodeURIComponent(theme);
        var res = await fetch(url, { method: 'POST' });
        var data = await res.json();
        if (link) link.style.display = 'block';
        btn.textContent = '✅ ' + data.sites + ' site(s), ' + data.pages + ' pages';
      } catch(e) {
        btn.textContent = '❌ Generation failed';
      }
    });
  }

  var saveBtn = document.getElementById('btn-save');
  if (saveBtn) {
    saveBtn.addEventListener('click', async function() {
      var title = document.getElementById('field-title').value;
      var slug = document.getElementById('field-slug').value;
      var content = document.getElementById('field-content').value;
      var status = document.getElementById('field-status').value;
      saveBtn.disabled = true;
      var prev = saveBtn.textContent;
      saveBtn.textContent = '⏳ Saving…';
      try {
        var res = await fetch('/api/save', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ title: title, slug: slug, content: content, status: status })
        });
        if (!res.ok) {
          var err = await res.json().catch(function() { return {}; });
          throw new Error(err.error || ('HTTP ' + res.status));
        }
        saveBtn.textContent = '✅ Saved';
      } catch(e) {
        saveBtn.textContent = '❌ Save failed';
      } finally {
        setTimeout(function() { saveBtn.disabled = false; saveBtn.textContent = prev; }, 1500);
      }
    });
  }

  var aiBtn = document.getElementById('ai-btn');
  var aiPrompt = document.getElementById('ai-prompt');
  if (aiBtn && aiPrompt) {
    aiBtn.addEventListener('click', async function() {
      var prompt = aiPrompt.value;
      if (!prompt) return;
      aiBtn.disabled = true;
      aiBtn.textContent = '⏳';
      try {
        var res = await fetch('/api/ai/design', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ prompt: prompt })
        });
        var config = await res.json();
        if (config.error) throw new Error(config.error);

        var root = document.documentElement;
        root.style.setProperty('--bg-color', config.bg_color);
        root.style.setProperty('--text-color', config.text_color);
        root.style.setProperty('--accent-color', config.accent_color);
        root.style.setProperty('--border-color', config.border_color);
        root.style.setProperty('--card-bg', config.card_bg);

        var shadow = config.shadow_depth === 'elevated' ? '0 10px 25px -5px rgba(0,0,0,0.3)' : config.shadow_depth === 'subtle' ? '0 4px 6px -1px rgba(0,0,0,0.1)' : 'none';
        var radius = config.border_radius === 'round' ? '2rem' : config.border_radius === 'soft' ? '0.75rem' : config.border_radius === 'sharp' ? '0' : '0.5rem';
        var spacing = config.spacing_scale === 'airy' ? '4rem' : config.spacing_scale === 'compact' ? '1rem' : '2rem';

        root.style.setProperty('--shadow', shadow);
        root.style.setProperty('--radius', radius);
        root.style.setProperty('--spacing', spacing);

        document.body.className = 'layout-' + config.layout_style;

        var styleTag = document.getElementById('ai-flourish');
        if (!styleTag) {
          styleTag = document.createElement('style');
          styleTag.id = 'ai-flourish';
          document.head.appendChild(styleTag);
        }
        styleTag.textContent = config.custom_flourish;

        var exists = Array.from(picker.options).some(function(o) { return o.value === config.name; });
        if (!exists) {
          var o = document.createElement('option');
          o.value = config.name; o.textContent = '✨ ' + config.name;
          picker.appendChild(o);
          picker.value = config.name;
        } else {
          picker.value = config.name;
        }
        aiBtn.textContent = 'Design'; aiBtn.disabled = false;
      } catch(e) {
        aiBtn.textContent = '❌';
        setTimeout(function() { aiBtn.textContent = 'Design'; aiBtn.disabled = false; }, 2000);
      }
    });
  }
})();
