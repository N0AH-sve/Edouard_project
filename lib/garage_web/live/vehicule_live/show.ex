defmodule GarageWeb.VehiculeLive.Show do
  @moduledoc "Fiche véhicule : caractéristiques et historique complet."
  use GarageWeb, :live_view

  alias Garage.Atelier
  alias Garage.Atelier.Client
  alias Garage.Atelier.Intervention
  alias Garage.Atelier.Vehicule

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      reglages={@reglages}
      titre={@vehicule.immatriculation}
      actif={:vehicules}
    >
      <:onglets>
        <Layouts.onglet navigate={~p"/vehicules"} icone="hero-arrow-left">
          Tous les véhicules
        </Layouts.onglet>
        <Layouts.onglet navigate={~p"/vehicules/#{@vehicule}"} icone="hero-truck" actif>
          Fiche
        </Layouts.onglet>
      </:onglets>

      <:actions>
        <.link
          navigate={~p"/vehicules/#{@vehicule}/modifier"}
          class="inline-flex items-center gap-2 rounded-full border border-base-300 px-5 py-2.5 text-sm font-medium transition hover:border-primary hover:text-primary"
        >
          <.icon name="hero-pencil-square" class="size-4" /> Modifier
        </.link>
        <.link
          navigate={~p"/interventions/nouvelle?vehicule=#{@vehicule.id}"}
          class="inline-flex items-center gap-2 rounded-full bg-primary px-5 py-2.5 text-sm font-semibold text-primary-content transition hover:bg-secondary"
        >
          <.icon name="hero-plus" class="size-4" /> Nouvelle intervention
        </.link>
      </:actions>

      <div class="space-y-6 p-6">
        <header class="flex flex-wrap items-center gap-3">
          <span class="rounded-lg bg-neutral px-3 py-1.5 font-mono text-base font-bold text-neutral-content">
            {@vehicule.immatriculation}
          </span>
          <span class="text-lg font-semibold">
            {[@vehicule.marque, @vehicule.modele] |> Enum.reject(&is_nil/1) |> Enum.join(" ")}
          </span>
          <.link
            :if={@vehicule.client}
            navigate={~p"/clients/#{@vehicule.client}"}
            class="ml-auto inline-flex items-center gap-2 text-sm hover:text-primary hover:underline"
          >
            <.icon name="hero-user" class="size-4" />
            {Client.nom_complet(@vehicule.client)}
          </.link>
        </header>

        <section class="grid grid-cols-2 gap-4 lg:grid-cols-5">
          <.champ libelle="Année" valeur={@vehicule.annee && to_string(@vehicule.annee)} />
          <.champ libelle="Carburant" valeur={Vehicule.libelle_carburant(@vehicule.carburant)} />
          <.champ libelle="Kilométrage" valeur={kilometrage(@vehicule.kilometrage)} />
          <.champ libelle="VIN" valeur={@vehicule.vin} />
          <div class="rounded-xl border border-base-300 px-4 py-3">
            <p class="text-xs font-semibold uppercase tracking-wide text-base-content/40">
              Prochain CT
            </p>
            <p class="mt-1.5">
              <span class={classe_ct(@vehicule.date_prochain_ct)}>
                {date_fr(@vehicule.date_prochain_ct) || "non renseigné"}
              </span>
            </p>
          </div>
        </section>

        <section :if={@vehicule.notes not in [nil, ""]} class="rounded-xl bg-base-200 p-4">
          <p class="text-xs font-semibold uppercase tracking-wide text-base-content/40">Notes</p>
          <p class="mt-1 whitespace-pre-line text-sm">{@vehicule.notes}</p>
        </section>

        <.live_component
          module={GarageWeb.Composants.Documents}
          id="documents-vehicule"
          rattachement={{:vehicule, @vehicule.id}}
        />

        <section class="space-y-3">
          <div class="flex items-baseline justify-between">
            <h2 class="font-semibold">
              Historique
              <span class="ml-1 rounded-full bg-base-200 px-2 py-0.5 text-xs text-base-content/60">
                {length(@vehicule.interventions)}
              </span>
            </h2>
            <p :if={@vehicule.interventions != []} class="text-sm text-base-content/60">
              Total facturé&nbsp;:
              <span class="font-semibold text-base-content">
                {Intervention.formater_euros(@total)}
              </span>
            </p>
          </div>

          <p
            :if={@vehicule.interventions == []}
            class="rounded-xl border border-dashed border-base-300 px-4 py-10 text-center text-sm text-base-content/50"
          >
            Aucune intervention enregistrée pour ce véhicule.
          </p>

          <div
            :if={@vehicule.interventions != []}
            class="overflow-hidden rounded-xl border border-base-300"
          >
            <table class="table-garage w-full text-left">
              <thead>
                <tr>
                  <th>Date</th>
                  <th>Type</th>
                  <th>Description</th>
                  <th class="text-right">Km</th>
                  <th class="text-right">Montant</th>
                  <th>Statut</th>
                </tr>
              </thead>
              <tbody>
                <tr :for={i <- @vehicule.interventions}>
                  <td class="whitespace-nowrap tabular-nums">{date_fr(i.date)}</td>
                  <td class="whitespace-nowrap">{Intervention.libelle_type(i.type)}</td>
                  <td>
                    <.link
                      navigate={~p"/interventions/#{i}"}
                      class="hover:text-primary hover:underline"
                    >
                      {i.description || "—"}
                    </.link>
                    <p :if={i.pieces not in [nil, ""]} class="text-xs text-base-content/50">
                      {i.pieces}
                    </p>
                  </td>
                  <td class="text-right tabular-nums">{kilometrage(i.kilometrage)}</td>
                  <td class="whitespace-nowrap text-right tabular-nums">
                    {Intervention.formater_euros(i.montant_centimes)}
                  </td>
                  <td>
                    <span class={Intervention.pastille_statut(i.statut)}>
                      {Intervention.libelle_statut(i.statut)}
                    </span>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end

  attr :libelle, :string, required: true
  attr :valeur, :string, default: nil

  defp champ(assigns) do
    ~H"""
    <div class="rounded-xl border border-base-300 px-4 py-3">
      <p class="text-xs font-semibold uppercase tracking-wide text-base-content/40">{@libelle}</p>
      <p class="mt-1 text-sm font-medium">{if @valeur in [nil, ""], do: "—", else: @valeur}</p>
    </div>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    vehicule = Atelier.get_vehicule!(id)

    # Seules les interventions réellement dues comptent dans le total :
    # un devis non accepté n'est pas du chiffre d'affaires.
    total =
      vehicule.interventions
      |> Enum.reject(&(&1.statut == :devis))
      |> Enum.map(& &1.montant_centimes)
      |> Enum.sum()

    {:ok,
     socket
     |> assign(:page_title, vehicule.immatriculation)
     |> assign(:vehicule, vehicule)
     |> assign(:total, total)}
  end

  @impl true
  def handle_info({:message_documents, type, message}, socket) do
    {:noreply, put_flash(socket, type, message)}
  end

  defp kilometrage(nil), do: nil

  defp kilometrage(km) do
    km
    |> Integer.to_string()
    |> String.reverse()
    |> String.replace(~r/(\d{3})(?=\d)/, "\\1\u00A0")
    |> String.reverse()
    |> Kernel.<>("\u00A0km")
  end

  defp date_fr(nil), do: nil
  defp date_fr(d), do: Calendar.strftime(d, "%d/%m/%Y")

  defp classe_ct(nil), do: "pastille pastille-neutre"

  defp classe_ct(date) do
    jours = Date.diff(date, Date.utc_today())

    cond do
      jours < 0 -> "pastille pastille-danger"
      jours <= 60 -> "pastille pastille-attente"
      true -> "pastille pastille-succes"
    end
  end
end
