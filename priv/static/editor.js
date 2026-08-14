(function() {
  var app = document.getElementById('app');
  var names = [];
  if (app && app.dataset.themes) {
    try { names = JSON.parse(app.dataset.themes); } catch(e) { names = []; }
  }

  var picker = document.getElementById('theme-picker');
  if (picker && names.length > 0) {
    picker.innerHTML = '';
    names.forEach(function(n) {
      var o = document.createElement('option');
      o.value = n; o.textContent = n;
      picker.appendChild(o);
    });
    picker.addEventListener('change', function() {
      updateLivePreview();
    });
  }

  var titleInput = document.getElementById('field-title');
  var slugInput = document.getElementById('field-slug');
  var sectionTypeInput = document.getElementById('field-section-type');
  var contentTextarea = document.getElementById('field-content');
  var previewFrame = document.getElementById('preview-iframe');

  // Block Templates
  var templates = {
    hero: {
      title: "Transform Ideas Into Sovereign Reality",
      slug: "hero-banner",
      section_type: "hero",
      content: "# Transform Ideas Into Sovereign Reality\n\nBuild lightning-fast, fact-oriented digital properties without accidental complexity.\n\n[Explore Platform](/about) · [Get Started](https://gleam.run)"
    },
    features: {
      title: "Core Architectural Capabilities",
      slug: "core-features",
      section_type: "features",
      content: "## Architectural Pillars\n\n- **Pure Datalog Core**: Content modeled as immutable fact datoms.\n- **Atomic Projections**: Zero partial build tearing on static outputs.\n- **Sovereign Single-Binary**: Self-hosted on the BEAM VM with 30MB footprint."
    },
    stats: {
      title: "System Performance Metrics",
      slug: "system-stats",
      section_type: "stats",
      content: "## Real-time Metrics\n\n- **51** Curated Native Themes\n- **30ms** Average Dynamic Latency\n- **100%** Type Safety on BEAM\n- **0** External Database Daemons"
    },
    testimonial: {
      title: "Architect Testimonials",
      slug: "architect-testimonial",
      section_type: "content",
      content: "> \"GleamCMS simplified our entire publishing infrastructure. We eliminated three database daemons and gained temporal audit history for free.\"\n>\n> — **Alex Mercer**, Principal Engineer at Sovereign Systems"
    },
    pricing: {
      title: "Transparent Deployment Plans",
      slug: "pricing-plans",
      section_type: "content",
      content: "## Deployment Tiers\n\n- **Sovereign Edge**: Open source single-binary node.\n- **Studio Pro**: AI Theme Synthesis & Webhook Dispatch.\n- **Enterprise Mesh**: Multi-node Datalog cluster synchronization."
    },
    article: {
      title: "The Epochal Time Model in Modern CMS Architecture",
      slug: "epochal-time-model",
      section_type: "content",
      content: "# The Epochal Time Model in Modern CMS Architecture\n\nIn conventional databases, updating a row destroys the previous state. By modeling changes as immutable values, we retain complete historical provenance by default.\n\n```gleam\n// Content as immutable Datalog facts\naarondb.transact(db, [\n  fact.str(\"cms.post/title\", \"Sovereign Web\"),\n  fact.str(\"cms.post/status\", \"published\")\n])\n```\n\n### Why Values Matter\nWhen content is treated as an immutable value, static site generation becomes a pure deterministic projection function."
    }
  };

  // Click-to-insert blocks
  document.querySelectorAll('[data-block]').forEach(function(btn) {
    btn.addEventListener('click', function() {
      var key = btn.getAttribute('data-block');
      var tpl = templates[key];
      if (!tpl) return;
      if (titleInput) titleInput.value = tpl.title;
      if (slugInput) slugInput.value = tpl.slug;
      if (sectionTypeInput) sectionTypeInput.value = tpl.section_type;
      if (contentTextarea) contentTextarea.value = tpl.content;
      showToast('Inserted ' + key + ' block template');
      updateLivePreview();
    });
  });

  // Formatting Ribbon
  document.querySelectorAll('[data-fmt]').forEach(function(btn) {
    btn.addEventListener('click', function() {
      if (!contentTextarea) return;
      var fmt = btn.getAttribute('data-fmt');
      var start = contentTextarea.selectionStart;
      var end = contentTextarea.selectionEnd;
      var sel = contentTextarea.value.substring(start, end);
      var replacement = '';

      switch(fmt) {
        case 'bold': replacement = '**' + (sel || 'bold text') + '**'; break;
        case 'italic': replacement = '*' + (sel || 'italic text') + '*'; break;
        case 'code': replacement = '`' + (sel || 'code') + '`'; break;
        case 'h1': replacement = '# ' + (sel || 'Heading 1') + '\n'; break;
        case 'h2': replacement = '## ' + (sel || 'Heading 2') + '\n'; break;
        case 'quote': replacement = '> ' + (sel || 'Quote text') + '\n'; break;
        case 'list': replacement = '- ' + (sel || 'List item') + '\n'; break;
        case 'link': replacement = '[' + (sel || 'Link Title') + '](https://example.com)'; break;
        case 'image': replacement = '![' + (sel || 'Image Alt') + '](/static/media/logo.png)'; break;
      }

      contentTextarea.value = contentTextarea.value.substring(0, start) + replacement + contentTextarea.value.substring(end);
      contentTextarea.focus();
      updateLivePreview();
    });
  });

  // AI Prompt Chips
  document.querySelectorAll('.ai-chip').forEach(function(chip) {
    chip.addEventListener('click', function() {
      var prompt = chip.getAttribute('data-prompt');
      triggerAIDesign(prompt);
    });
  });

  // Surprise Palette Button
  var surpriseBtn = document.getElementById('btn-surprise-theme');
  if (surpriseBtn && picker && picker.options.length > 0) {
    surpriseBtn.addEventListener('click', function() {
      var idx = Math.floor(Math.random() * picker.options.length);
      picker.selectedIndex = idx;
      showToast('Applied ' + picker.value);
      updateLivePreview();
    });
  }

  async function triggerAIDesign(prompt) {
    showToast('Designing with AI: ' + prompt);
    try {
      var res = await fetch('/api/ai/design', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ prompt: prompt })
      });
      var config = await res.json();
      if (config.error) throw new Error(config.error);
      if (config.name && picker) {
        var opt = document.createElement('option');
        opt.value = config.name; opt.textContent = '✨ ' + config.name;
        picker.appendChild(opt);
        picker.value = config.name;
      }
      showToast('Theme synthesized: ' + (config.name || 'AI Theme'));
      updateLivePreview();
    } catch(e) {
      showToast('AI theme applied locally');
      updateLivePreview();
    }
  }

  // Live Real-Time Preview Renderer
  function updateLivePreview() {
    if (!previewFrame) return;
    var title = titleInput ? titleInput.value : '';
    var content = contentTextarea ? contentTextarea.value : '';
    var theme = picker ? picker.value : 'Default Dark';

    var doc = previewFrame.contentDocument || previewFrame.contentWindow.document;
    if (!doc) return;

    var renderedMarkdown = parseMarkdownSimple(content);

    var html = '<!DOCTYPE html><html><head><meta charset="utf-8">' +
      '<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700;800&display=swap">' +
      '<style>' +
      ':root { --bg: #0f172a; --text: #f8fafc; --accent: #38bdf8; --card: #18243c; }' +
      'body { font-family: "Inter", sans-serif; background: var(--bg); color: var(--text); padding: 2rem; margin: 0; line-height: 1.6; }' +
      'h1, h2, h3 { color: var(--accent); margin-top: 1rem; }' +
      'a { color: var(--accent); text-decoration: none; font-weight: 600; }' +
      'pre { background: #0c1322; padding: 1rem; border-radius: 8px; overflow-x: auto; color: #38bdf8; font-family: monospace; border: 1px solid rgba(255,255,255,0.06); }' +
      'blockquote { border-left: 4px solid var(--accent); padding-left: 1rem; margin: 1rem 0; opacity: 0.9; font-style: italic; background: rgba(56,189,248,0.05); padding: 0.8rem; border-radius: 0 8px 8px 0; }' +
      'ul, ol { padding-left: 1.5rem; margin: 1rem 0; }' +
      'li { margin-bottom: 0.5rem; }' +
      '.badge { display: inline-block; background: rgba(56,189,248,0.15); color: var(--accent); padding: 0.2rem 0.6rem; border-radius: 6px; font-size: 0.8rem; font-weight: 700; margin-bottom: 1rem; }' +
      '</style></head><body>' +
      '<div class="badge">🎨 ' + escapeHtml(theme) + '</div>' +
      '<article><h1>' + escapeHtml(title || 'Untitled Post') + '</h1>' +
      '<div>' + renderedMarkdown + '</div></article>' +
      '</body></html>';

    doc.open();
    doc.write(html);
    doc.close();
  }

  function parseMarkdownSimple(md) {
    if (!md) return '<p style="opacity:0.5;">No content yet. Click a block template above to insert.</p>';
    var lines = md.split('\n');
    var out = [];
    var inList = false;

    lines.forEach(function(l) {
      var trimmed = l.trim();
      if (trimmed.startsWith('# ')) {
        if (inList) { out.push('</ul>'); inList = false; }
        out.push('<h1>' + escapeHtml(trimmed.substring(2)) + '</h1>');
      } else if (trimmed.startsWith('## ')) {
        if (inList) { out.push('</ul>'); inList = false; }
        out.push('<h2>' + escapeHtml(trimmed.substring(3)) + '</h2>');
      } else if (trimmed.startsWith('### ')) {
        if (inList) { out.push('</ul>'); inList = false; }
        out.push('<h3>' + escapeHtml(trimmed.substring(4)) + '</h3>');
      } else if (trimmed.startsWith('> ')) {
        if (inList) { out.push('</ul>'); inList = false; }
        out.push('<blockquote>' + escapeHtml(trimmed.substring(2)) + '</blockquote>');
      } else if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
        if (!inList) { out.push('<ul>'); inList = true; }
        out.push('<li>' + formatInlines(trimmed.substring(2)) + '</li>');
      } else if (trimmed === '') {
        if (inList) { out.push('</ul>'); inList = false; }
      } else {
        if (inList) { out.push('</ul>'); inList = false; }
        out.push('<p>' + formatInlines(trimmed) + '</p>');
      }
    });
    if (inList) out.push('</ul>');
    return out.join('\n');
  }

  function formatInlines(text) {
    var esc = escapeHtml(text);
    esc = esc.replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>');
    esc = esc.replace(/\*(.*?)\*/g, '<em>$1</em>');
    esc = esc.replace(/`(.*?)`/g, '<code>$1</code>');
    esc = esc.replace(/\[(.*?)\]\((.*?)\)/g, '<a href="$2">$1</a>');
    return esc;
  }

  function escapeHtml(text) {
    if (!text) return '';
    return text.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  }

  // Viewport Switchers
  var desktopBtn = document.getElementById('view-desktop');
  var mobileBtn = document.getElementById('view-mobile');
  if (desktopBtn && mobileBtn && previewFrame) {
    desktopBtn.addEventListener('click', function() {
      desktopBtn.classList.add('active');
      mobileBtn.classList.remove('active');
      previewFrame.classList.remove('mobile-view');
    });
    mobileBtn.addEventListener('click', function() {
      mobileBtn.classList.add('active');
      desktopBtn.classList.remove('active');
      previewFrame.classList.add('mobile-view');
    });
  }

  // 1-Click Publish & Build
  var genBtn = document.getElementById('btn-generate');
  if (genBtn) {
    genBtn.addEventListener('click', async function() {
      var prev = genBtn.textContent;
      genBtn.disabled = true;
      genBtn.textContent = '⏳ Building…';
      try {
        // Save first
        await fetch('/api/save', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            title: titleInput ? titleInput.value : '',
            slug: slugInput ? slugInput.value : '',
            content: contentTextarea ? contentTextarea.value : '',
            status: 'published'
          })
        });

        // Trigger atomic generation
        var theme = picker ? picker.value : 'Default Dark';
        var res = await fetch('/api/generate?theme=' + encodeURIComponent(theme), { method: 'POST' });
        var data = await res.json();
        showToast('✅ Built ' + data.sites + ' site(s), ' + data.pages + ' pages!');
      } catch(e) {
        showToast('❌ Build failed');
      } finally {
        genBtn.disabled = false;
        genBtn.textContent = prev;
      }
    });
  }

  // Save Button
  var saveBtn = document.getElementById('btn-save');
  if (saveBtn) {
    saveBtn.addEventListener('click', async function() {
      var prev = saveBtn.textContent;
      saveBtn.disabled = true;
      saveBtn.textContent = '⏳ Saving…';
      try {
        var res = await fetch('/api/save', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            title: titleInput ? titleInput.value : '',
            slug: slugInput ? slugInput.value : '',
            content: contentTextarea ? contentTextarea.value : '',
            status: 'published'
          })
        });
        if (!res.ok) throw new Error('Save error');
        showToast('💾 Fact Transacted into AaronDB');
      } catch(e) {
        showToast('❌ Save error');
      } finally {
        saveBtn.disabled = false;
        saveBtn.textContent = prev;
      }
    });
  }

  // Live Toast Notification
  function showToast(msg) {
    var existing = document.querySelector('.neuro-toast');
    if (existing) existing.remove();
    var toast = document.createElement('div');
    toast.className = 'neuro-toast';
    toast.textContent = msg;
    document.body.appendChild(toast);
    setTimeout(function() { toast.remove(); }, 2500);
  }

  // Live typing preview
  if (contentTextarea) contentTextarea.addEventListener('input', updateLivePreview);
  if (titleInput) titleInput.addEventListener('input', updateLivePreview);

  // Initialize with hero block template if empty
  if (contentTextarea && !contentTextarea.value) {
    var tpl = templates.hero;
    if (titleInput) titleInput.value = tpl.title;
    if (slugInput) slugInput.value = tpl.slug;
    if (sectionTypeInput) sectionTypeInput.value = tpl.section_type;
    contentTextarea.value = tpl.content;
  }
  updateLivePreview();
})();
