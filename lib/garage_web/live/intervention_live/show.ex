defmodule GarageWeb.InterventionLive.Show do
  @moduledoc "Détail d'une intervention."
  use GarageWeb, :live_view

  alias Garage.Atelier
  alias Garage.Atelier.Client
  alias Garage.Atelier.Intervention

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      reglages={@reglages}
      titre={Intervention.libelle_type(@intervention.type)}
      actif={:interventions}
    >
      <:onglets>
        <Layouts.onglet navigate={~p"/interventions"} icone="hero-arrow-left">
          Toutes les interventions
        </Layouts.onglet>
        <Layouts.onglet
          navigate={~p"/interventions/#{@intervention}"}
          icone="hero-wrench-screwdriver"
          actif
        >
          Détail
        </Layouts.onglet>
      </:onglets>

      <:actions>
        <.link
          navigate={~p"/interventions/#{@intervention}/modifier"}
          class="inline-flex items-center gap-2 rounded-full border border-base-300 px-5 py-2.5 text-sm font-medium transition hover:border-primary hover:text-primary"
        >
          <.icon name="hero-pencil-square" class="size-4" /> Modifier
        </.link>
      </:actions>

      <div class="space-y-6 p-6">
        <header class="flex flex-wrap items-center gap-4">
          <div>
            <p class="text-2xl font-bold">
              {Intervention.formater_euros(@intervention.montant_centimes)}
            </p>
            <p class="mt-1 text-sm text-base-content/60">
              {Intervention.libelle_type(@intervention.type)} · {date_fr(@intervention.date)}
            </p>
          </div>
          <span class={["ml-auto", Intervention.pastille_statut(@intervention.statut)]}>
            {Intervention.libelle_statut(@intervention.statut)}
          </span>
        </header>

        <section class="grid grid-cols-1 gap-4 sm:grid-cols-3">
          <div class="rounded-xl border border-base-300 px-4 py-3">
            <p class="text-xs font-semibold uppercase tracking-wide text-base-content/40">
              Véhicule
            </p>
            <.link
              :if={@intervention.vehicule}
              navigate={~p"/vehicules/#{@intervention.vehicule}"}
              class="mt-1 inline-block font-mono text-sm font-semibold hover:text-primary"
            >
              {@intervention.vehicule.immatriculation}
            </.link>
            <p :if={@intervention.vehicule} class="text-xs text-base-content/50">
              {[@intervention.vehicule.marque, @intervention.vehicule.modele]
              |> Enum.reject(&is_nil/1)
              |> Enum.join(" ")}
            </p>
          </div>

          <div class="rounded-xl border border-base-300 px-4 py-3">
            <p class="text-xs font-semibold uppercase tracking-wide text-base-content/40">Client</p>
            <.link
              :if={@intervention.vehicule && @intervention.vehicule.client}
              navigate={~p"/clients/#{@intervention.vehicule.client}"}
              class="mt-1 inline-block text-sm font-medium hover:text-primary"
            >
              {Client.nom_complet(@intervention.vehicule.client)}
            </.link>
          </div>

          <div class="rounded-xl border border-base-300 px-4 py-3">
            <p class="text-xs font-semibold uppercase tracking-wide text-base-content/40">
              Kilométrage relevé
            </p>
            <p class="mt-1 text-sm font-medium tabular-nums">
              {kilometrage(@intervention.kilometrage)}
            </p>
          </div>
        </section>

        <section :if={@intervention.description not in [nil, ""]}>
          <p class="text-xs font-semibold uppercase tracking-wide text-base-content/40">
            Description
          </p>
          <p class="mt-1 whitespace-pre-line text-sm">{@intervention.description}</p>
        </section>

        <section :if={@intervention.pieces not in [nil, ""]} class="rounded-xl bg-base-200 p-4">
          <p class="text-xs font-semibold uppercase tracking-wide text-base-content/40">
            Pièces utilisées
          </p>
          <p class="mt-1 whitespace-pre-line text-sm">{@intervention.pieces}</p>
        </section>
        <.live_component
          module={GarageWeb.Composants.Documents}
          id="documents-intervention"
          rattachement={{:intervention, @intervention.id}}
        />
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    intervention = Atelier.get_intervention!(id)

    {:ok,
     socket
     |> assign(:page_title, Intervention.libelle_type(intervention.type))
     |> assign(:intervention, intervention)}
  end

  @impl true
  def handle_info({:message_documents, type, message}, socket) do
    {:noreply, put_flash(socket, type, message)}
  end

  defp date_fr(nil), do: "—"
  defp date_fr(d), do: Calendar.strftime(d, "%d/%m/%Y")

  defp kilometrage(nil), do: "—"

  defp kilometrage(km) do
    km
    |> Integer.to_string()
    |> String.reverse()
    |> String.replace(~r/(\d{3})(?=\d)/, "\\1\u00A0")
    |> String.reverse()
    |> Kernel.<>("\u00A0km")
  end
end
