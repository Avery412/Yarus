import { Button, Field, MaterialIcon, PostForm, routes } from "./ui";

const navigation = [
  [routes.balances, "Остатки", "▤"],
  [routes.products, "Товары", "◇"],
  [routes.warehouses, "Склады", "▥"],
  [routes.movements, "Журнал операций", "⇄"],
];

function Wordmark() {
  return <a href="/" className="wordmark" aria-label="ЯРУС, главная">ЯРУС</a>;
}

export function Layout({ user, screen, notice, alert, children }) {
  const path = window.location.pathname;
  return <div className="workspace">
    <a className="skip" href="#content">К содержимому</a>
    <aside className="sidebar">
      <div className="brand"><Wordmark /><span>СКЛАДСКОЙ УЧЁТ</span></div>
      {user && <>
        <nav aria-label="Разделы">
          {navigation.map(([href, label, symbol]) => {
            const active = path === href || path.startsWith(href + "/");
            return <a key={href} className={active ? "active" : undefined} href={href}
              aria-current={active ? "location" : undefined}><span aria-hidden="true">{symbol}</span>{label}</a>;
          })}
        </nav>
        <div className="account">
          <span>{user.email}</span>
          <small>{user.role === "manager" ? "Управляющий складом" : "Оператор склада"}</small>
          <PostForm action="/session" verb="delete"><button className="text-button">Выйти <span aria-hidden="true">↗</span></button></PostForm>
        </div>
      </>}
    </aside>
    <main className="workspace-main" id="content">
      {notice && <div className="alert alert-success" role="status">{notice}</div>}
      {alert && <div className="alert alert-error" role="alert">{alert}</div>}
      {children}
    </main>
  </div>;
}

export function Home({ user, image, icons }) {
  const entry = user ? routes.balances : "/session/new";
  return <main className="home">
    <section className="hero" style={{ backgroundImage: "linear-gradient(90deg,#14201bf5,#14201b31),url(" + image + ")" }}>
      <header className="hero-header"><Wordmark /><a href={entry}>{user ? "Рабочий кабинет" : "Войти"} <span aria-hidden="true">↗</span></a></header>
      <div className="hero-copy">
        <p className="eyebrow">СКЛАДСКОЙ УЧЁТ СТРОЙМАТЕРИАЛОВ</p>
        <h1>Каждый материал<br />на своём месте.</h1>
        <p>Каталог, текущие остатки и история прихода и расхода по каждому складу.</p>
        <Button href={entry}>{user ? "Открыть остатки" : "Войти в ЯРУС"} <span aria-hidden="true">→</span></Button>
      </div>
    </section>
    <section className="home-features" aria-label="Разделы учёта">
      {[
        ["Товары", "Плитка", "Артикулы, единицы измерения и карточки материалов.", routes.products],
        ["Склады", "Кирпич", "Адреса складов и данные по запасам.", routes.warehouses],
        ["Остатки", "Ламинат", "Количество и минимальный порог по каждой паре товар–склад.", routes.balances],
        ["Журнал операций", "Цемент", "Приход, расход, автор и время каждой записи.", routes.movements],
      ].map(([title, icon, description, path]) => <a className="feature" key={path} href={path}>
        <MaterialIcon name={icon} icons={icons} /><h2>{title}</h2><p>{description}</p>
      </a>)}
    </section>
  </main>;
}

export function SignIn({ image, email, alert, error }) {
  return <main className="sign-in">
    <section className="sign-image" style={{ backgroundImage: "linear-gradient(0deg,#14201bd9,#14201b35),url(" + image + ")" }}>
      <Wordmark /><p>Склад стройматериалов</p>
    </section>
    <section className="sign-panel">
      <a className="back-link" href="/">← На главную</a>
      <h1>Вход в ЯРУС</h1>
      <p className="muted">Войдите под своей учётной записью.</p>
      {(error || alert) && <div className="alert alert-error" role="alert">{error || alert}</div>}
      <PostForm action="/session" className="form-fields">
        <Field label="Электронная почта" type="email" name="email" value={email} autoComplete="username" required />
        <Field label="Пароль" type="password" name="password" autoComplete="current-password" required />
        <Button>Войти</Button>
      </PostForm>
    </section>
  </main>;
}
