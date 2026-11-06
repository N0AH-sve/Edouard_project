defmodule GarageWeb.Router do
  use GarageWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {GarageWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  # Tant que le garagiste n'a pas rempli son profil, tout est renvoyé
  # vers l'écran de bienvenue.
  pipeline :profil_requis do
    plug GarageWeb.ProfilRequis
  end

  # Inverse : l'écran de bienvenue disparaît une fois le profil saisi.
  pipeline :profil_absent do
    plug :rediriger_si_configure
  end

  # --- Premier démarrage -----------------------------------------------------

  scope "/", GarageWeb do
    pipe_through [:browser, :profil_absent]

    live_session :bienvenue,
      on_mount: {GarageWeb.ProfilRequis, :interdire_si_configure} do
      live "/bienvenue", BienvenueLive, :new
    end
  end

  # --- Anniversaire ----------------------------------------------------------
  # Hors de la live_session principale : son hook renverrait ici en boucle.

  scope "/", GarageWeb do
    pipe_through :browser

    live_session :anniversaire,
      on_mount: {GarageWeb.ProfilRequis, :anniversaire} do
      live "/anniversaire", AnniversaireLive, :show
    end
  end

  # --- Application -----------------------------------------------------------

  scope "/", GarageWeb do
    pipe_through [:browser, :profil_requis]

    get "/", PageController, :home

    # Les PDF sont hors de priv/static : ils sont servis par un
    # contrôleur, qui relit le chemin en base à partir de l'identifiant.
    get "/documents/:id", DocumentController, :show
    get "/documents/:id/telecharger", DocumentController, :download

    live_session :atelier,
      on_mount: {GarageWeb.ProfilRequis, :exiger_profil} do
      # L'ordre compte : « /clients/nouveau » doit être reconnu avant
      # « /clients/:id », sinon « nouveau » serait pris pour un identifiant.
      live "/clients", ClientLive.Index, :index
      live "/clients/nouveau", ClientLive.Form, :new
      live "/clients/:id", ClientLive.Show, :show
      live "/clients/:id/modifier", ClientLive.Form, :edit

      live "/vehicules", VehiculeLive.Index, :index
      live "/vehicules/nouveau", VehiculeLive.Form, :new
      live "/vehicules/:id", VehiculeLive.Show, :show
      live "/vehicules/:id/modifier", VehiculeLive.Form, :edit

      live "/interventions", InterventionLive.Index, :index
      live "/interventions/nouvelle", InterventionLive.Form, :new
      live "/interventions/:id", InterventionLive.Show, :show
      live "/interventions/:id/modifier", InterventionLive.Form, :edit

      live "/reglages", ReglagesLive, :edit
    end
  end

  defp rediriger_si_configure(conn, opts),
    do: GarageWeb.ProfilRequis.rediriger_si_configure(conn, opts)

  # LiveDashboard en développement uniquement.
  if Application.compile_env(:garage, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: GarageWeb.Telemetry
    end
  end
end
