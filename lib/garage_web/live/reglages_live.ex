defmodule GarageWeb.ReglagesLive do
  @moduledoc """
  Modification du profil après le premier démarrage.
  """
  use GarageWeb, :live_view

  alias Garage.Profil

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} reglages={@reglages} titre="Mon profil" actif={nil}>
      <:onglets>
        <Layouts.onglet navigate={~p"/reglages"} icone="hero-user" actif>
          Mon profil
        </Layouts.onglet>
      </:onglets>

      <.form for={@form} id="formulaire-reglages" phx-change="valider" phx-submit="enregistrer">
        <div class="space-y-6 p-6">
          <section class="space-y-4">
            <h2 class="text-sm font-semibold text-base-content/50">Identité</h2>
            <div class="grid grid-cols-1 gap-x-5 sm:grid-cols-2">
              <.input field={@form[:prenom]} type="text" label="Prénom" required />
              <.input field={@form[:nom]} type="text" label="Nom" required />
            </div>
          </section>

          <section class="space-y-4">
            <h2 class="text-sm font-semibold text-base-content/50">Société</h2>
            <.input field={@form[:societe]} type="text" label="Nom de la société" required />
            <.input field={@form[:email_pro]} type="email" label="E-mail professionnel" required />
          </section>

          <section class="space-y-2">
            <h2 class="text-sm font-semibold text-base-content/50">Date de naissance</h2>
            <%!--
              Affichée, mais pas modifiable : le changeset refuserait la
              modification de toute façon. Un champ saisissable dont la
              valeur est ignorée en silence serait trompeur.
            --%>
            <div class="flex items-center gap-3 rounded-xl border border-base-300 bg-base-200 px-4 py-3">
              <.icon name="hero-cake" class="size-5 text-base-content/40" />
              <span class="font-medium">{date_fr(@reglages.date_naissance)}</span>
              <.icon name="hero-lock-closed" class="ml-auto size-4 text-base-content/30" />
            </div>
            <p class="text-xs text-base-content/50">
              Renseignée au premier démarrage, elle n'est plus modifiable.
            </p>
          </section>
        </div>

        <footer class="flex items-center justify-end gap-3 border-t border-base-300 px-6 py-4">
          <.link
            navigate={~p"/clients"}
            class="rounded-full px-5 py-2.5 text-sm font-medium text-base-content/60 hover:bg-base-200"
          >
            Annuler
          </.link>
          <button
            type="submit"
            phx-disable-with="Enregistrement…"
            class="rounded-full bg-primary px-6 py-2.5 text-sm font-semibold text-primary-content transition hover:bg-secondary"
          >
            Enregistrer
          </button>
        </footer>
      </.form>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    reglages = socket.assigns.reglages

    {:ok,
     socket
     |> assign(:page_title, "Mon profil")
     |> assign(:form, to_form(Profil.change_reglages(reglages)))}
  end

  defp date_fr(nil), do: "non renseignée"
  defp date_fr(date), do: Calendar.strftime(date, "%d/%m/%Y")

  @impl true
  def handle_event("valider", %{"reglages" => params}, socket) do
    changeset = Profil.change_reglages(socket.assigns.reglages, params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("enregistrer", %{"reglages" => params}, socket) do
    case Profil.enregistrer(params) do
      {:ok, reglages} ->
        {:noreply,
         socket
         |> assign(:reglages, reglages)
         |> assign(:form, to_form(Profil.change_reglages(reglages)))
         |> put_flash(:info, "Profil enregistré.")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
    end
  end
end
