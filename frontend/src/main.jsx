import { createRoot } from "react-dom/client";
import "@fontsource/inter/cyrillic-400.css";
import "@fontsource/inter/cyrillic-600.css";
import "@fontsource/inter/latin-400.css";
import "@fontsource/inter/latin-600.css";
import { Home, SignIn, Layout } from "./layout";
import { Catalog, CatalogDetail, CatalogForm } from "./catalog";
import { Balances, Balance, Movements, Movement, MovementForm } from "./inventory";
import { PageHeading, Button, Empty } from "./ui";
import "./styles.css";

const screens = {
  products: Catalog,
  warehouses: Catalog,
  product: CatalogDetail,
  warehouse: CatalogDetail,
  product_form: CatalogForm,
  warehouse_form: CatalogForm,
  inventory_balances: Balances,
  inventory_balance: Balance,
  stock_movements: Movements,
  stock_movement: Movement,
  movement_form: MovementForm,
};

function App({ screen, props, user, notice, alert, warehouse_image, icons }) {
  if (screen === "home") return <Home user={user} image={warehouse_image} icons={icons} />;
  if (screen === "sign_in") return <SignIn image={warehouse_image} alert={alert} {...props} />;

  const Screen = screens[screen];
  return (
    <Layout user={user} screen={screen} notice={notice} alert={alert}>
      {Screen ? <Screen {...props} screen={screen} icons={icons} /> : (
        <>
          <PageHeading title="Страница не найдена" />
          <Empty title="Запись недоступна" description="Проверьте адрес или вернитесь к складскому учёту.">
            <Button href={user ? "/inventory_balances" : "/"}>На главную</Button>
          </Empty>
        </>
      )}
    </Layout>
  );
}

const data = JSON.parse(document.getElementById("yarus-data").textContent);
createRoot(document.getElementById("yarus-root")).render(<App {...data} />);
