// views/js/feed.js
export class Feed {
  /**
   * @param {HTMLElement} root  Contenedor del feed (sección que envuelve todo)
   * @param {Object} opts
   *  - apiBase: '/FootBook'
   *  - endpoint: '/api/feed'
   *  - worldcupsLight: '/FootBook/api/worldcups/light'
   *  - listSelector: '#feed-list'
   *  - loadingSelector: '#feed-loading'
   *  - formSelector: '#feed-filters-form'
   *  - worldcupSelector: '#filter-worldcup'
   *  - orderSelector: '#filter-order'
   *  - pageSize: 10
   *  - extraParams: {}      // parámetros extra que viajan en la URL (ej. { user_id: 123 } para perfil)
   *  - renderItem: (post)=>HTMLElement   // opcional: custom renderer
   */
  constructor(root, opts = {}) {
    if (!root) throw new Error('Feed: root requerido');

    this.root      = root;
    this.opts      = Object.assign({
      apiBase: '/FootBook',
      endpoint: '/api/feed',
      worldcupsLight: '/FootBook/api/worldcups/light',
      listSelector: '#feed-list',
      loadingSelector: '#feed-loading',
      formSelector: '#feed-filters-form',
      worldcupSelector: '#filter-worldcup',
      orderSelector: '#filter-order',
      pageSize: 10,
      extraParams: {},
      renderItem: null,
    }, opts);

    // Estado
    this.reqVersion = 0;
    this.lastId  = 0;
    this.loading = false;
    this.ended   = false;
    this.filters = {
      worldcupId: '',
      orderBy: 'cronologico',
    };

    // DOM
    this.$list    = this.root.querySelector(this.opts.listSelector);
    this.$loading = this.root.querySelector(this.opts.loadingSelector);
    this.$form    = document.querySelector(this.opts.formSelector);
    this.$selWC   = document.querySelector(this.opts.worldcupSelector);
    this.$selOrd  = document.querySelector(this.opts.orderSelector);

    if (!this.$list)    throw new Error('Feed: listSelector no encontrado');
    if (!this.$loading) throw new Error('Feed: loadingSelector no encontrado');

    // Sentinel para infinite scroll
    this.$sentinel = document.createElement('div');
    this.$sentinel.id = 'feed-sentinel';
    this.root.appendChild(this.$sentinel);

    this.init();
  }

  async init() {
    this.#bindFilters();
    await this.#fillWorldcups();
    this.#setupObserver();
    this.loadMore({ reset: true });
  }

  destroy() {
    if (this.io) this.io.disconnect();
  }

  // ----------- Público -----------

  /**
   * Cambia/mezcla parámetros extra de URL (ej. { user_id: 123 } para perfil)
   */
  setExtraParams(obj = {}) {
    this.opts.extraParams = { ...this.opts.extraParams, ...obj };
  }

  /**
   * Cambia filtros de UI programáticamente
   */
  setFilters({ worldcupId = '', orderBy = 'cronologico' } = {}) {
    this.filters.worldcupId = worldcupId;
    this.filters.orderBy    = orderBy;
  }

  /**
   * Fuerza recarga con los filtros/params actuales
   */
  async reload() {
    await this.loadMore({ reset: true });
  }

  // ----------- Interno -----------

  #ajaxGET(url) {
    return new Promise((resolve, reject) => {
      const xhr = new XMLHttpRequest();
      xhr.open('GET', url, true);
      xhr.withCredentials = true;
      xhr.setRequestHeader('Accept', 'application/json');
      xhr.onreadystatechange = () => {
        if (xhr.readyState !== 4) return;
        const raw = xhr.responseText || '';
        try {
          const i = raw.indexOf('{'), j = raw.lastIndexOf('}');
          const json = JSON.parse(i >= 0 && j >= i ? raw.slice(i, j + 1) : raw);
          if (xhr.status >= 200 && xhr.status < 300 && json?.ok) resolve(json);
          else reject(new Error(json?.error || 'Error API'));
        } catch {
          reject(new Error('Respuesta no-JSON del API'));
        }
      };
      xhr.onerror = () => reject(new Error('Error de red'));
      xhr.send();
    });
  }

  #buildUrl() {
    const { apiBase, endpoint, pageSize, extraParams } = {
      apiBase: this.opts.apiBase,
      endpoint: this.opts.endpoint,
      pageSize: this.opts.pageSize,
      extraParams: this.opts.extraParams || {}
    };

    const q = new URLSearchParams();
    q.set('limit', pageSize);
    if (this.lastId) q.set('after', this.lastId);

    // filtros
    if (this.filters.worldcupId !== '') q.set('worldcup_id', this.filters.worldcupId);
    if (this.filters.orderBy)           q.set('order', this.filters.orderBy);

    // extra
    Object.entries(extraParams).forEach(([k,v]) => {
      if (v !== undefined && v !== null && v !== '') q.set(k, v);
    });

    return `${apiBase}${endpoint}?${q.toString()}`;
  }

#renderDefault(post) {
  const avatar = post.avatar_b64
    ? `data:image/*;base64,${post.avatar_b64}`
    : `${this.opts.apiBase}/img/default.jpg`;

  const wc  = [post.worldcup_name, post.worldcup_year].filter(Boolean).join(' ');
  const cat = post.category_name || '';

  // --- NUEVO: soporte de imagen o video ---
  let mediaHTML = '';

  if (post.media_b64) {
    // Si el back manda mime-type o indicador
    const t = (post.media_type || '').toLowerCase();

    if (t.includes('video') || t === 'video') {
      mediaHTML = `
        <video class="w-100 rounded mb-2" controls preload="metadata">
          <source src="data:video/mp4;base64,${post.media_b64}" type="video/mp4">
          Tu navegador no soporta video.
        </video>`;
    } else {
      mediaHTML = `
        <img class="img-fluid rounded mb-2"
             src="data:image/*;base64,${post.media_b64}"
             alt="Post media">`;
    }
  }

  // --- CONTENIDO ORIGINAL ---
  const el = document.createElement('div');
  el.className = 'card mb-3 shadow-sm';
  el.innerHTML = `
    <div class="card-body">
      <div class="d-flex mb-2 align-items-center">
        <img src="${avatar}" class="rounded-circle me-2" width="40" height="40" alt="User">
        <div>
          <strong>${post.username ?? 'Usuario'}</strong>
          <span class="text-muted small">en ${wc}</span>
          <span class="badge bg-secondary ms-2">${cat}</span>
        </div>
      </div>

      ${post.title ? `<h6 class="mb-1">${post.title}</h6>` : ''}
      <p class="mb-2">${post.description ?? ''}</p>

      ${mediaHTML}

      <div>
        <button class="btn btn-sm btn-outline-success me-2">${post.likes_count ?? 0}</button>
        <button class="btn btn-sm btn-outline-secondary">${post.comments_count ?? 0}</button>
      </div>
    </div>`;
  return el;
}


  #resetState() {
    this.lastId  = 0;
    this.ended   = false;
    this.loading = false;
    this.$list.innerHTML = '';
  }

  async loadMore({ reset = false } = {}) {
    if (this.loading || this.ended) return;

    const myVersion = ++this.reqVersion;

    if (reset) this.#resetState();

    this.loading = true;
    this.$loading.classList.remove('d-none');

    const url = this.#buildUrl();

    try {
      const { data } = await this.#ajaxGET(url);

      if (myVersion !== this.reqVersion) return; // respuesta vieja

      if (!Array.isArray(data) || data.length === 0) {
        this.ended = true;
        return;
      }

      const frag = document.createDocumentFragment();
      for (const p of data) {
        const item = (typeof this.opts.renderItem === 'function')
          ? this.opts.renderItem(p)
          : this.#renderDefault(p);
        frag.appendChild(item);
      }
      this.$list.appendChild(frag);

      this.lastId = data[data.length - 1].id;
      if (data.length < this.opts.pageSize) this.ended = true;

    } catch (err) {
      console.error('[Feed] Error:', err);
    } finally {
      if (myVersion === this.reqVersion) {
        this.loading = false;
        this.$loading.classList.add('d-none');
      }
    }
  }

  #setupObserver() {
    this.io = new IntersectionObserver((entries) => {
      entries.forEach(e => {
        if (e.isIntersecting) this.loadMore();
      });
    }, { rootMargin: '400px 0px' });
    this.io.observe(this.$sentinel);
  }

  async #fillWorldcups() {
    // Si no hay select de mundiales en esta pantalla, omite
    if (!this.$selWC) return;
    try {
      const payload = await this.#ajaxGET(this.opts.worldcupsLight);
      if (!payload?.ok || !Array.isArray(payload.data)) return;

      // limpia excepto "Todas las copas"
      this.$selWC.querySelectorAll('option:not([value=""])').forEach(o => o.remove());

      payload.data.forEach(cup => {
        const opt = document.createElement('option');
        opt.value = cup.id;          // el back espera worldcup_id (id)
        opt.textContent = `${cup.name} ${cup.year}`;
        this.$selWC.appendChild(opt);
      });
    } catch (err) {
      console.warn('[Feed] No se pudo cargar worldcups:', err.message);
    }
  }

  #bindFilters() {
    if (!this.$form) return; // pantalla sin filtros

    this.$form.addEventListener('submit', async (ev) => {
      ev.preventDefault();

      // lee UI
      if (this.$selWC)  this.filters.worldcupId = this.$selWC.value ? parseInt(this.$selWC.value, 10) : '';
      if (this.$selOrd) this.filters.orderBy    = this.$selOrd.value || 'cronologico';

      this.reqVersion++;
      await this.loadMore({ reset: true });
    });
  }
}
