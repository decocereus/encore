/// Injected into music.youtube.com. Reports player state to Swift and exposes `window.__ytmbar` commands.
let bridgeScript = #"""
(() => {
  if (window.__ytmbar) return;
  const video = () => document.querySelector('#movie_player video') || document.querySelector('video');
  const player = () => document.querySelector('#movie_player');
  const bar = (sel) => document.querySelector('ytmusic-player-bar ' + sel);
  const text = (el) => ((el && el.textContent) || '').trim();
  const queueItems = () => [...document.querySelectorAll('ytmusic-player-queue ytmusic-player-queue-item')];

  // Queue <img> tags are lazy-loaded placeholders, so read the thumbnail from the element's data.
  function queueThumb(el) {
    const data = el.data || (el.__data && el.__data.data);
    const thumbs = data && data.thumbnail && data.thumbnail.thumbnails;
    if (thumbs && thumbs.length) return thumbs[thumbs.length - 1].url;
    const img = el.querySelector('img');
    return img && img.src && !img.src.startsWith('data:') ? img.src : '';
  }

  function queue() {
    return queueItems().map((el, index) => ({
      index,
      title: text(el.querySelector('.song-title')),
      artist: text(el.querySelector('.byline')),
      thumb: queueThumb(el),
      selected: el.hasAttribute('selected'),
    }));
  }

  function read() {
    const v = video();
    const p = player();
    const md = navigator.mediaSession && navigator.mediaSession.metadata;
    const cfg = window.ytcfg;
    return {
      type: 'state',
      title: (md && md.title) || '',
      artist: (md && md.artist) || '',
      album: (md && md.album) || '',
      art: md && md.artwork && md.artwork.length ? md.artwork[md.artwork.length - 1].src : '',
      playing: !!v && !v.paused && !v.ended,
      position: p && p.getCurrentTime ? p.getCurrentTime() : (v ? v.currentTime : 0),
      duration: p && p.getDuration ? p.getDuration() : (v && isFinite(v.duration) ? v.duration : 0),
      volume: p && p.getVolume ? p.getVolume() : (v ? Math.round(v.volume * 100) : 100),
      signedIn: !!(cfg && cfg.get && cfg.get('LOGGED_IN')),
      queue: queue(),
    };
  }

  let lastKey = '';
  function report(force) {
    const s = read();
    const key = JSON.stringify([s.title, s.artist, s.art, s.playing, Math.round(s.duration), s.volume, s.signedIn,
      s.queue.map(q => q.title + (q.selected ? '*' : ''))]);
    if (!force && key === lastKey) return;
    lastKey = key;
    window.webkit.messageHandlers.ytm.postMessage(s);
  }

  // Ducking scales the <video> element under YouTube's own volume, so the user's saved volume never changes.
  let duckFactor = 1;
  function applyDuck() {
    const v = video();
    const p = player();
    if (!v) return;
    const base = p && p.getVolume ? p.getVolume() / 100 : 1;
    const target = Math.max(0, Math.min(1, base * duckFactor));
    if (Math.abs(v.volume - target) > 0.005) v.volume = target;
  }

  for (const ev of ['play', 'playing', 'pause', 'seeked', 'ended', 'waiting', 'loadedmetadata', 'volumechange']) {
    document.addEventListener(ev, () => report(true), true);
  }
  // YouTube rewrites the element volume on track changes; keep the duck applied.
  document.addEventListener('volumechange', () => { if (duckFactor < 1) applyDuck(); }, true);
  document.addEventListener('loadedmetadata', () => { if (duckFactor < 1) applyDuck(); }, true);
  setInterval(() => report(false), 1000);

  const style = document.createElement('style');
  style.textContent = '::-webkit-scrollbar { display: none !important; }';
  document.documentElement.appendChild(style);

  // InnerTube is the JSON API the YouTube Music page itself calls. Signed-in requests carry a SAPISIDHASH.
  async function innertube(path, body) {
    const cfg = window.ytcfg;
    const headers = {
      'Content-Type': 'application/json',
      'X-Goog-AuthUser': String(cfg.get('SESSION_INDEX') || 0),
      'X-Origin': location.origin,
    };
    const sapisid = document.cookie.match(/(?:^|;\s*)(?:SAPISID|__Secure-3PAPISID)=([^;]+)/);
    if (sapisid) {
      const ts = Math.floor(Date.now() / 1000);
      const digest = await crypto.subtle.digest('SHA-1', new TextEncoder().encode(`${ts} ${sapisid[1]} ${location.origin}`));
      const hex = [...new Uint8Array(digest)].map(b => b.toString(16).padStart(2, '0')).join('');
      headers.Authorization = `SAPISIDHASH ${ts}_${hex}`;
    }
    const res = await fetch(`/youtubei/v1/${path}?prettyPrint=false&key=${cfg.get('INNERTUBE_API_KEY')}`, {
      method: 'POST',
      credentials: 'include',
      headers,
      body: JSON.stringify({ context: cfg.get('INNERTUBE_CONTEXT'), ...body }),
    });
    if (!res.ok) throw new Error(`InnerTube ${path} returned HTTP ${res.status}`);
    return res.json();
  }

  function listItems(node, out = []) {
    if (!node || typeof node !== 'object') return out;
    if (node.musicResponsiveListItemRenderer) { out.push(node.musicResponsiveListItemRenderer); return out; }
    for (const key in node) listItems(node[key], out);
    return out;
  }

  const columnText = (col) =>
    ((col && col.musicResponsiveListItemFlexColumnRenderer && col.musicResponsiveListItemFlexColumnRenderer.text.runs) || [])
      .map(r => r.text).join('');

  function toTrack(r) {
    const overlay = r.overlay && r.overlay.musicItemThumbnailOverlayRenderer;
    const watch = overlay && overlay.content.musicPlayButtonRenderer.playNavigationEndpoint;
    const videoId = (r.playlistItemData && r.playlistItemData.videoId) || (watch && watch.watchEndpoint && watch.watchEndpoint.videoId);
    if (!videoId) return null;
    const thumbs = (r.thumbnail && r.thumbnail.musicThumbnailRenderer.thumbnail.thumbnails) || [];
    return {
      videoId,
      title: columnText(r.flexColumns && r.flexColumns[0]),
      subtitle: columnText(r.flexColumns && r.flexColumns[1]),
      thumb: thumbs.length ? thumbs[thumbs.length - 1].url : '',
    };
  }

  const runsText = (t) => ((t && t.runs) || []).map(r => r.text).join('');
  const lastThumb = (thumbs) => (thumbs && thumbs.length ? thumbs[thumbs.length - 1].url : '');

  function twoRowItems(node, out = []) {
    if (!node || typeof node !== 'object') return out;
    if (node.musicTwoRowItemRenderer) { out.push(node.musicTwoRowItemRenderer); return out; }
    for (const key in node) twoRowItems(node[key], out);
    return out;
  }

  function toCollection(r) {
    const browse = r.navigationEndpoint && r.navigationEndpoint.browseEndpoint;
    if (!browse || !browse.browseId) return null;
    const thumbs = r.thumbnailRenderer && r.thumbnailRenderer.musicThumbnailRenderer
      && r.thumbnailRenderer.musicThumbnailRenderer.thumbnail.thumbnails;
    return { id: browse.browseId, title: runsText(r.title), subtitle: runsText(r.subtitle), thumb: lastThumb(thumbs) };
  }

  function findKey(node, key) {
    if (!node || typeof node !== 'object') return null;
    if (node[key]) return node[key];
    for (const k in node) { const found = findKey(node[k], key); if (found) return found; }
    return null;
  }

  function continuationToken(node) {
    const item = findKey(node, 'continuationItemRenderer');
    const command = item && findKey(item, 'continuationCommand');
    if (command && command.token) return command.token;
    const legacy = findKey(node, 'nextContinuationData');
    return legacy && legacy.continuation;
  }

  // Long playlists arrive in pages of about 100; follow the continuation tokens.
  async function allTracks(json) {
    const seen = new Set();
    const tracks = [];
    const add = (node) => listItems(node).map(toTrack).filter(Boolean).forEach(t => {
      if (!seen.has(t.videoId)) { seen.add(t.videoId); tracks.push(t); }
    });
    add(json);
    let token = continuationToken(json);
    for (let page = 0; token && page < 30; page++) {
      const more = await innertube('browse', { continuation: token });
      add(more);
      token = continuationToken(more);
    }
    return tracks;
  }

  const SONGS_FILTER = 'EgWKAQIIAWoMEA4QChADEAQQCRAF';

  window.__ytmbar = {
    report: () => report(true),
    toggle() {
      const b = bar('#play-pause-button');
      if (b) return b.click();
      const v = video();
      if (v) v.paused ? v.play() : v.pause();
    },
    play() { const v = video(); if (v && v.paused) window.__ytmbar.toggle(); },
    pause() { const v = video(); if (v && !v.paused) window.__ytmbar.toggle(); },
    next() { const b = bar('.next-button'); if (b) b.click(); },
    prev() { const b = bar('.previous-button'); if (b) b.click(); },
    seek(t) {
      const p = player();
      if (p && p.seekTo) p.seekTo(t, true);
      else if (video()) video().currentTime = t;
    },
    setVolume(n) {
      const p = player();
      if (p && p.setVolume) { p.setVolume(n); if (n > 0 && p.unMute) p.unMute(); }
      else if (video()) video().volume = n / 100;
      report(true);
    },
    playQueueItem(i) {
      const el = queueItems()[i];
      if (!el) return;
      (el.querySelector('ytmusic-play-button-renderer') || el.querySelector('.song-info') || el).click();
    },
    playVideo(videoId) {
      const app = document.querySelector('ytmusic-app');
      const endpoint = { watchEndpoint: { videoId } };
      if (app) app.dispatchEvent(new CustomEvent('yt-navigate', { bubbles: true, composed: true, detail: { endpoint } }));
      else location.href = '/watch?v=' + encodeURIComponent(videoId);
    },
    duck(factor) { duckFactor = factor; applyDuck(); },
    // Playlists saved or created by the signed-in account. Liked Music ("VLLM") is part of this list.
    async account() {
      const json = await innertube('account/account_menu', {});
      const header = findKey(json, 'activeAccountHeaderRenderer') || {};
      const runs = header.accountName && header.accountName.runs;
      return runs && runs[0] ? runs[0].text : '';
    },
    async library() {
      const json = await innertube('browse', { browseId: 'FEmusic_liked_playlists' });
      return twoRowItems(json).map(toCollection).filter(c => c && c.id.startsWith('VL') && c.id !== 'VLSE');
    },
    async playlist(browseId) {
      const json = await innertube('browse', { browseId });
      const header = findKey(json, 'musicResponsiveHeaderRenderer') || findKey(json, 'musicDetailHeaderRenderer') || {};
      const thumbs = findKey(header, 'thumbnails');
      return {
        id: browseId,
        title: runsText(header.title),
        subtitle: [runsText(header.subtitle), runsText(header.secondSubtitle)].filter(Boolean).join(' · '),
        thumb: lastThumb(thumbs),
        tracks: await allTracks(json),
      };
    },
    playPlaylist(browseId, videoId) {
      const app = document.querySelector('ytmusic-app');
      const playlistId = browseId.replace(/^VL/, '');
      const endpoint = { watchEndpoint: videoId ? { videoId, playlistId } : { playlistId } };
      if (app) app.dispatchEvent(new CustomEvent('yt-navigate', { bubbles: true, composed: true, detail: { endpoint } }));
    },
    async home() {
      const json = await innertube('browse', { browseId: 'FEmusic_home' });
      return twoRowItems(json).map(toCollection).filter(c => c && c.id.startsWith('VL'));
    },
    async search(query) {
      const json = await innertube('search', { query, params: SONGS_FILTER });
      return listItems(json).map(toTrack).filter(Boolean).slice(0, 30);
    },
  };
})();
"""#
