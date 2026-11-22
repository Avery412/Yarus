export const routes = {
  products: "/products",
  warehouses: "/warehouses",
  balances: "/inventory_balances",
  movements: "/stock_movements",
};

export const movementTypes = { receipt: "Приход", issue: "Расход" };

export function queryPath(path, params = {}) {
  const query = new URLSearchParams();
  for (const [key, value] of Object.entries(params)) {
    if (typeof value === "number" || (typeof value === "string" && value.trim())) query.set(key, value);
  }
  const search = query.toString();
  return search ? path + "?" + search : path;
}

export function amount(value) {
  return new Intl.NumberFormat("ru-RU", {
    minimumFractionDigits: 3,
    maximumFractionDigits: 3,
  }).format(Number(value));
}

export function dateTime(value) {
  return value ? new Intl.DateTimeFormat("ru-RU", { dateStyle: "medium", timeStyle: "short" }).format(new Date(value)) : "—";
}

export function Button({ href, secondary = false, children, ...props }) {
  const className = "button" + (secondary ? " button-secondary" : "");
  return href ? <a className={className} href={href} {...props}>{children}</a>
    : <button type="submit" className={className} {...props}>{children}</button>;
}

export function Back({ href, children }) {
  return <a className="back-link" href={href}><span aria-hidden="true">←</span> {children}</a>;
}

export function PageHeading({ title, description, actions }) {
  return <header className="page-heading">
    <div><h1>{title}</h1>{description && <p>{description}</p>}</div>
    {actions && <div className="actions">{actions}</div>}
  </header>;
}

export function Empty({ title, description, children }) {
  return <section className="empty"><h2>{title}</h2><p>{description}</p>{children}</section>;
}

export function DetailList({ fields }) {
  return <dl className="detail-list">
    {fields.map(([label, value]) => <div key={label}><dt>{label}</dt><dd>{value || "—"}</dd></div>)}
  </dl>;
}

export function Table({ label, headers, rows }) {
  return <div className="table-scroll" tabIndex={0} role="region" aria-label={label}>
    <table>
      <thead><tr>{headers.map(header => <th scope="col" key={header}>{header}</th>)}</tr></thead>
      <tbody>{rows.map(({ id, cells }) => <tr key={id}>
        {cells.map((cell, index) => <td key={headers[index]}>{cell}</td>)}
      </tr>)}</tbody>
    </table>
  </div>;
}

export function Pagination({ path, filters, page }) {
  const link = (number) => queryPath(path, { ...filters, per_page: page.per_page, page: number });
  return <nav className="pagination" aria-label="Страницы">
    <span>Всего записей: {page.total_count}</span>
    <div>
      {page.previous_page && <a href={link(page.previous_page)}>← Назад</a>}
      <span>Страница {page.page} из {Math.max(page.total_pages, 1)}</span>
      {page.next_page && <a href={link(page.next_page)}>Далее →</a>}
    </div>
  </nav>;
}

export function Field({ label, name, value, type = "text", options, placeholder, errors = [], ...props }) {
  const id = name.replace(/[^\w-]/g, "-");
  const textValue = typeof value === "string" || typeof value === "number" ? String(value) : "";
  const common = {
    ...props, name, id, defaultValue: textValue,
    "aria-invalid": errors.length > 0 || undefined,
    "aria-describedby": errors.length ? id + "-error" : undefined,
  };

  return <div className="field">
    <label htmlFor={id}>{label}</label>
    {options ? <select {...common}>
      <option value="">{placeholder || "Выберите значение"}</option>
      {textValue && !options.some(option => String(option.value) === textValue) && (
        <option value={textValue}>Недоступное значение ({textValue})</option>
      )}
      {options.map(option => <option key={option.value} value={option.value}>{option.label}</option>)}
    </select> : type === "textarea" ? <textarea rows={4} placeholder={placeholder} {...common} />
      : <input type={type} placeholder={placeholder} {...common} />}
    {errors.length > 0 && <span className="field-error" id={id + "-error"}>{errors.join(". ")}</span>}
  </div>;
}

export function Filters({ path, filters, searchPlaceholder, children }) {
  return <form className="filters" action={path} method="get" role="search" aria-label="Поиск и фильтры">
    <Field label="Поиск" name="search" type="search" value={filters.search} placeholder={searchPlaceholder} />
    {children}
    <Field label="На странице" name="per_page" value={filters.per_page || "20"} options={
      [...new Set([20, 50, 100, Math.min(Number(filters.per_page) || 20, 100)])]
        .filter(n => n > 0).sort((a, b) => a - b).map(n => ({ value: n, label: n }))
    } />
    <div className="filter-actions"><Button>Применить</Button><a href={path}>Сбросить</a></div>
  </form>;
}

export function ErrorSummary({ errors = {} }) {
  const entries = Object.values(errors).flat();
  if (!entries.length) return null;
  return <div className="alert alert-error" role="alert"><strong>Проверьте данные</strong>
    <ul>{[...new Set(entries)].map(error => <li key={error}>{error}</li>)}</ul>
  </div>;
}

export function PostForm({ action, verb, children, className }) {
  function preventDuplicate(event) {
    const form = event.currentTarget;
    if (form.dataset.submitting) {
      event.preventDefault();
      return;
    }
    form.dataset.submitting = "true";
    window.addEventListener("pageshow", () => { delete form.dataset.submitting; }, { once: true });
  }

  return <form action={action} method="post" className={className} onSubmit={preventDuplicate}>
    <input type="hidden" name="authenticity_token" value={document.querySelector("meta[name=csrf-token]")?.content || ""} />
    {verb && <input type="hidden" name="_method" value={verb} />}
    {children}
  </form>;
}

export function MaterialIcon({ name, icons }) {
  const types = [[/плитк|керамогранит/i, "tile"], [/кирпич/i, "brick"], [/ламинат/i, "laminate"],
    [/доск|брус|пиломат|древес/i, "timber"], [/ват|утепл/i, "insulation"], [/цемент|смесь|смес/i, "dry-mix"]];
  const icon = types.find(([pattern]) => pattern.test(name))?.[1];
  return icon ? <img className="material-icon" src={icons[icon]} width="34" height="34" alt="" />
    : <span className="material-icon material-fallback" aria-hidden="true">◇</span>;
}
