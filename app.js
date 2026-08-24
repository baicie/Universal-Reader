const books = [
  { title: '设计中的设计', author: '原研哉', format: 'EPUB', type: 'reflow', progress: 37, cover: 'cover-design', coverTitle: '设计中的设计', recent: 12 },
  { title: 'The Creative Act', author: 'Rick Rubin', format: 'EPUB', type: 'reflow', progress: 0, cover: 'cover-sand', coverTitle: 'The\nCreative\nAct', recent: 11 },
  { title: 'Designing Data-Intensive Applications', author: 'Martin Kleppmann', format: 'PDF', type: 'fixed', progress: 64, cover: 'cover-blue', coverTitle: 'Designing\nData-\nIntensive\nApplications', recent: 10 },
  { title: '小王子', author: 'Antoine de Saint-Exupéry', format: 'EPUB', type: 'reflow', progress: 82, cover: 'cover-red', coverTitle: '小王子', recent: 9 },
  { title: 'The Art of Doing Science', author: 'Richard Hamming', format: 'PDF', type: 'fixed', progress: 15, cover: 'cover-cream', coverTitle: 'The Art\nof Doing\nScience', recent: 8 },
  { title: 'Head First Design Patterns', author: 'Eric Freeman', format: 'EPUB', type: 'reflow', progress: 0, cover: 'cover-charcoal', coverTitle: 'Head First\nDesign\nPatterns', recent: 7 },
  { title: '百年孤独', author: '加西亚·马尔克斯', format: 'EPUB', type: 'reflow', progress: 25, cover: 'cover-lilac', coverTitle: '百年\n孤独', recent: 6 },
  { title: 'The Way of Code', author: 'Reed Berkowitz', format: 'CBZ', type: 'comic', progress: 0, cover: 'cover-olive', coverTitle: 'The Way\nof Code', recent: 5 },
  { title: '银河系漫游手册', author: '奥杜', format: 'CBZ', type: 'comic', progress: 48, cover: 'cover-yellow', coverTitle: '银河系\n漫游手册', recent: 4 },
  { title: 'Rust 程序设计语言', author: 'Steve Klabnik', format: 'MD', type: 'reflow', progress: 71, cover: 'cover-slate', coverTitle: 'Rust\n程序设计\n语言', recent: 3 },
  { title: 'On Writing Well', author: 'William Zinsser', format: 'MOBI', type: 'reflow', progress: 0, cover: 'cover-sand', coverTitle: 'On\nWriting\nWell', recent: 2 },
  { title: '夜航西飞', author: '柏瑞尔·马卡姆', format: 'EPUB', type: 'reflow', progress: 11, cover: 'cover-red', coverTitle: '夜航\n西飞', recent: 1 }
];

const state = { filter: 'all', type: 'all', query: '', view: 'grid', sort: 'recent' };
const grid = document.querySelector('#book-grid');
const empty = document.querySelector('#empty-state');
const toast = document.querySelector('#toast');

function showToast(message) {
  toast.textContent = message;
  toast.classList.add('show');
  window.clearTimeout(showToast.timer);
  showToast.timer = window.setTimeout(() => toast.classList.remove('show'), 2600);
}

function visibleBooks() {
  return books.filter((book) => {
    const matchesQuery = !state.query || `${book.title} ${book.author} ${book.format}`.toLowerCase().includes(state.query.toLowerCase());
    const matchesType = state.type === 'all' || book.type === state.type;
    const matchesFilter = state.filter === 'all' || (state.filter === 'recent' && book.recent > 8) || (state.filter === 'reading' && book.progress > 0 && book.progress < 100) || (state.filter === 'favorites' && ['设计中的设计', '小王子', '百年孤独'].includes(book.title));
    return matchesQuery && matchesType && matchesFilter;
  }).sort((a, b) => state.sort === 'title' ? a.title.localeCompare(b.title, 'zh') : state.sort === 'progress' ? b.progress - a.progress : b.recent - a.recent);
}

function renderBooks() {
  const items = visibleBooks();
  grid.innerHTML = items.map((book) => `
    <article class="book-card" data-title="${book.title}">
      <div class="book-cover ${book.cover}">
        <span class="format-badge">${book.format}</span>
        <h3>${book.coverTitle.replaceAll('\n', '<br>')}</h3>
        <small>${book.author}</small>
      </div>
      <div class="book-info">
        <h3 title="${book.title}">${book.title}</h3>
        <p>${book.author}</p>
        ${book.progress ? `<div class="book-progress"><div class="progress-track"><span style="width: ${book.progress}%"></span></div><span>${book.progress}%</span></div>` : ''}
      </div>
    </article>`).join('');
  empty.classList.toggle('hidden', items.length > 0);
  grid.classList.toggle('hidden', items.length === 0);
}

function updatePageTitle() {
  const labels = { all: '全部书籍', recent: '最近阅读', reading: '正在阅读', favorites: '收藏' };
  document.querySelector('#page-title').textContent = labels[state.filter];
  document.querySelector('#page-subtitle').textContent = `${visibleBooks().length} 本书籍 · 最近同步于刚刚`;
}

function setFilter(filter) {
  state.filter = filter;
  document.querySelectorAll('.nav-item').forEach((item) => item.classList.toggle('active', item.dataset.filter === filter));
  renderBooks();
  updatePageTitle();
}

document.querySelectorAll('.nav-item').forEach((item) => item.addEventListener('click', (event) => { event.preventDefault(); setFilter(item.dataset.filter); }));
document.querySelectorAll('.filter-tab').forEach((tab) => tab.addEventListener('click', () => { state.type = tab.dataset.type; document.querySelectorAll('.filter-tab').forEach((item) => item.classList.toggle('active', item === tab)); renderBooks(); updatePageTitle(); }));
document.querySelector('#search-input').addEventListener('input', (event) => { state.query = event.target.value.trim(); renderBooks(); updatePageTitle(); });
document.querySelector('#sort-select').addEventListener('change', (event) => { state.sort = event.target.value; renderBooks(); });
document.querySelectorAll('.view-button').forEach((button) => button.addEventListener('click', () => { state.view = button.dataset.view; document.querySelectorAll('.view-button').forEach((item) => item.classList.toggle('active', item === button)); document.body.classList.toggle('list-view', state.view === 'list'); }));
document.querySelector('#clear-search').addEventListener('click', () => { state.query = ''; state.type = 'all'; document.querySelector('#search-input').value = ''; document.querySelectorAll('.filter-tab').forEach((item) => item.classList.toggle('active', item.dataset.type === 'all')); setFilter('all'); });
document.querySelector('#continue-button').addEventListener('click', () => showToast('正在打开《设计中的设计》'));
document.querySelector('#settings-button').addEventListener('click', () => showToast('设置中心即将开放'));
document.querySelector('#collapse-button').addEventListener('click', () => showToast('移动端会自动收起导航'));
document.querySelectorAll('.collection-item').forEach((item) => item.addEventListener('click', (event) => { event.preventDefault(); showToast('集合视图即将开放'); }));

const fileInput = document.querySelector('#file-input');
document.querySelector('#import-button').addEventListener('click', () => fileInput.click());
document.querySelector('#import-folder').addEventListener('click', () => fileInput.click());
fileInput.addEventListener('change', (event) => { const count = event.target.files.length; if (count) showToast(`已选择 ${count} 个文件，格式检测已就绪`); event.target.value = ''; });
grid.addEventListener('click', (event) => { const card = event.target.closest('.book-card'); if (card) showToast(`正在打开《${card.dataset.title}》`); });

document.addEventListener('keydown', (event) => { if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === 'k') { event.preventDefault(); document.querySelector('#search-input').focus(); } });
renderBooks();
