defmodule GarageWeb.BienvenueLive do
  @moduledoc """
  Premier démarrage : saisie du profil du garagiste.

  Cet écran n'apparaît qu'une fois. Dès que le profil existe, le plug
  `GarageWeb.ProfilRequis` renvoie vers le tableau des clients.
  """
  use GarageWeb, :live_view

  alias Garage.Profil

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.nue flash={@flash}>
      <div class="card bg-base-100 shadow-lg">
        <div class="card-body gap-6">
          <div class="space-y-2 text-center">
            <.icon name="hero-wrench-screwdriver" class="size-10 text-primary mx-auto" />
            <h1 class="text-2xl font-semibold">Bienvenue</h1>
            <p class="text-base-content/70 text-sm">
              Quelques informations pour commencer. Elles figureront sur vos
              documents et ne sont demandées qu'une seule fois.
            </p>
          </div>

          <.form for={@form} id="bienvenue-form" phx-change="validate" phx-submit="save">
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-x-4">
              <.input field={@form[:prenom]} type="text" label="Prénom" autocomplete="given-name" />
              <.input field={@form[:nom]} type="text" label="Nom" autocomplete="family-name" />
            </div>

            <.input
              field={@form[:societe]}
              type="text"
              label="Nom de la société"
              placeholder="Garage Durand"
              autocomplete="organization"
            />
            <.input
              field={@form[:email_pro]}
              type="email"
              label="E-mail professionnel"
              autocomplete="email"
            />
            <.input field={@form[:date_naissance]} type="date" label="Date de naissance" />

            <footer class="mt-6">
              <button
                type="submit"
                phx-disable-with="Enregistrement…"
                class="w-full rounded-full bg-primary px-6 py-3 text-sm font-semibold text-primary-content transition hover:bg-secondary"
              >
                Commencer
              </button>
            </footer>
          </.form>

          <p class="text-xs text-base-content/60 text-center">
            Ces données restent sur ce Mac. Elles ne sont envoyées à aucun serveur.
          </p>
        </div>
      </div>
    </Layouts.nue>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Bienvenue")
     |> assign(:form, to_form(Profil.change_reglages()))}
  end

  @impl true
  def handle_event("validate", %{"reglages" => params}, socket) do
    changeset = Profil.change_reglages(nil, params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"reglages" => params}, socket) do
    case Profil.enregistrer(params) do
      {:ok, _reglages} ->
        # push_navigate et non push_patch : on change de live_session,
        # il faut une reconnexion complète.
        {:noreply, push_navigate(socket, to: ~p"/clients")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
    end
  end
end
