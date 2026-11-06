defmodule GarageWeb.InterventionLive.Index do
  @moduledoc "Liste des interventions, filtrable par statut."
  use GarageWeb, :live_view

  alias Garage.Atelier
  alias Garage.Atelier.Client
  alias Garage.Atelier.Intervention

  @onglets [
    {nil, "Toutes", "hero-list-bullet"},
    {:en_cours, "En cours", "hero-wrench"},
    {:devis, "Devis", "hero-document-text"},
    {:facture, "À encaisser", "hero-banknotes"}
  ]

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :onglets_def, @onglets)

    ~H"""
    <Layouts.app
      flash={@flash}
      reglages={@reglages}
      titre="Interventions"
      actif={:interventions}
      recherche={@recherche}
      placeholder_recherche="Immatriculation, client, description…"
    >
      <:onglets>
        <Layouts.onglet
          :for={{statut, libelle, icone} <- @onglets_def}
          navigate={lien_onglet(statut)}
          icone={icone}
          actif={@statut == statut}
          compteur={Map.get(@compteurs, statut)}
        >
          {libelle}
        </Layouts.onglet>
      </:onglets>

      <:actions>
        <p class="mr-auto text-sm text-base-content/60">
          Encaissé&nbsp;:
          <span class="font-semibold text-base-content">
            {Intervention.formater_euros(@encaisse)}
          </span>
        </p>
        <.link
          navigate={~p"/interventions/nouvelle"}
          class="inline-flex items-center gap-2 rounded-full bg-primary px-5 py-2.5 text-sm font-semibold text-primary-content transition hover:bg-secondary"
        >
          <.icon name="hero-plus" class="size-4" /> Nouvelle intervention
        </.link>
      </:actions>

      <div :if={@interventions == []} class="px-6 py-16 text-center">
        <.icon name="hero-wrench-screwdriver" class="mx-auto size-10 text-base-content/20" />
        <p class="mt-4 font-medium">Aucune intervention à afficher.</p>
      </div>

      <div :if={@interventions != []} class="overflow-x-auto">
        <table class="table-garage w-full text-left">
          <thead>
            <tr>
              <th class="w-12 pl-5">
                <input
                  type="checkbox"
                  class="checkbox checkbox-sm checkbox-primary"
                  checked={@tout_coche}
                  phx-click="basculer_tout"
                  aria-label="Tout sélectionner"
                />
              </th>
              <th>Date</th>
              <th>Véhicule</th>
              <th>Client</th>
              <th>Type</th>
              <th class="text-right">Montant</th>
              <th>Statut</th>
              <th class="w-12"></th>
            </tr>
          </thead>
          <tbody>
            <tr
              :for={i <- @interventions}
              class={[MapSet.member?(@selection, i.id) && "ligne-selectionnee"]}
            >
              <td class="pl-5">
                <input
                  type="checkbox"
                  class="checkbox checkbox-sm checkbox-primary"
                  checked={MapSet.member?(@selection, i.id)}
                  phx-click="basculer"
                  phx-value-id={i.id}
                  aria-label="Sélectionner cette intervention"
                />
              </td>

              <td class="whitespace-nowrap tabular-nums">{date_fr(i.date)}</td>

              <td>
                <.link
                  :if={i.vehicule}
                  navigate={~p"/vehicules/#{i.vehicule}"}
                  class="rounded-md bg-base-200 px-2 py-1 font-mono text-xs hover:bg-primary/10 hover:text-primary"
                >
                  {i.vehicule.immatriculation}
                </.link>
              </td>

              <td>
                <.link
                  :if={i.vehicule && i.vehicule.client}
                  navigate={~p"/clients/#{i.vehicule.client}"}
                  class="hover:text-primary hover:underline"
                >
                  {Client.nom_complet(i.vehicule.client)}
                </.link>
              </td>

              <td>
                <.link
                  navigate={~p"/interventions/#{i}"}
                  class="font-medium hover:text-primary hover:underline"
                >
                  {Intervention.libelle_type(i.type)}
                </.link>
                <p :if={i.description} class="max-w-xs truncate text-xs text-base-content/50">
                  {i.description}
                </p>
              </td>

              <td class="whitespace-nowrap text-right font-medium tabular-nums">
                {Intervention.formater_euros(i.montant_centimes)}
              </td>

              <td>
                <span class={Intervention.pastille_statut(i.statut)}>
                  {Intervention.libelle_statut(i.statut)}
                </span>
              </td>

              <td class="pr-5 text-right">
                <.link
                  navigate={~p"/interventions/#{i}/modifier"}
                  title="Modifier"
                  class="inline-grid size-8 place-items-center rounded-full text-base-content/40 hover:bg-base-200 hover:text-base-content"
                >
                  <.icon name="hero-pencil-square" class="size-4" />
                </.link>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <Layouts.barre_selection nombre={MapSet.size(@selection)}>
        <Layouts.bouton_barre phx-click="marquer_payees">
          <.icon name="hero-check-circle" class="size-4" /> Marquer payées
        </Layouts.bouton_barre>
        <Layouts.bouton_barre
          danger
          phx-click="supprimer_selection"
          data-confirm="Supprimer les interventions sélectionnées ?"
        >
          <.icon name="hero-trash" class="size-4" /> Supprimer
        </Layouts.bouton_barre>
      </Layouts.barre_selection>
    </Layouts.app>
    """
  end

  defp lien_onglet(nil), do: ~p"/interventions"
  defp lien_onglet(statut), do: ~p"/interventions?statut=#{statut}"

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Interventions")
     |> assign(:recherche, "")
     |> assign(:selection, MapSet.new())}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    statut = parser_statut(params["statut"])
    {:noreply, socket |> assign(:statut, statut) |> charger()}
  end

  # On n'accepte que les statuts connus : String.to_atom/1 sur un
  # paramètre d'URL remplirait la table des atomes sans limite.
  defp parser_statut(nil), do: nil

  defp parser_statut(valeur) do
    Enum.find_value(@onglets, fn {statut, _, _} ->
      statut && to_string(statut) == valeur && statut
    end)
  end

  @impl true
  def handle_event("rechercher", %{"q" => q}, socket) do
    {:noreply, socket |> assign(:recherche, q) |> assign(:selection, MapSet.new()) |> charger()}
  end

  def handle_event("basculer", %{"id" => id}, socket) do
    id = String.to_integer(id)

    selection =
      if MapSet.member?(socket.assigns.selection, id),
        do: MapSet.delete(socket.assigns.selection, id),
        else: MapSet.put(socket.assigns.selection, id)

    {:noreply, socket |> assign(:selection, selection) |> calculer_tout_coche()}
  end

  def handle_event("basculer_tout", _params, socket) do
    selection =
      if socket.assigns.tout_coche,
        do: MapSet.new(),
        else: MapSet.new(socket.assigns.interventions, & &1.id)

    {:noreply, socket |> assign(:selection, selection) |> calculer_tout_coche()}
  end

  def handle_event("tout_deselectionner", _params, socket) do
    {:noreply, socket |> assign(:selection, MapSet.new()) |> calculer_tout_coche()}
  end

  def handle_event("marquer_payees", _params, socket) do
    n =
      socket.assigns.selection
      |> Enum.map(&Atelier.get_intervention!/1)
      |> Enum.count(fn i ->
        match?({:ok, _}, Atelier.update_intervention(i, %{"statut" => "paye"}))
      end)

    {:noreply,
     socket
     |> assign(:selection, MapSet.new())
     |> charger()
     |> put_flash(:info, "#{n} intervention#{s(n)} marquée#{s(n)} payée#{s(n)}.")}
  end

  def handle_event("supprimer_selection", _params, socket) do
    n =
      socket.assigns.selection
      |> Enum.map(&Atelier.get_intervention!/1)
      |> Enum.count(&match?({:ok, _}, Atelier.delete_intervention(&1)))

    {:noreply,
     socket
     |> assign(:selection, MapSet.new())
     |> charger()
     |> put_flash(:info, "#{n} intervention#{s(n)} supprimée#{s(n)}.")}
  end

  defp s(n) when n > 1, do: "s"
  defp s(_), do: ""

  defp charger(socket) do
    interventions =
      Atelier.list_interventions(
        recherche: socket.assigns.recherche,
        statut: socket.assigns.statut
      )

    compteurs =
      Map.new(@onglets, fn
        {nil, _, _} -> {nil, Atelier.count_interventions()}
        {statut, _, _} -> {statut, Atelier.count_interventions_par_statut(statut)}
      end)

    socket
    |> assign(:interventions, interventions)
    |> assign(:compteurs, compteurs)
    |> assign(:encaisse, Atelier.total_encaisse())
    |> calculer_tout_coche()
  end

  defp calculer_tout_coche(socket) do
    liste = socket.assigns[:interventions] || []
    sel = socket.assigns.selection
    assign(socket, :tout_coche, liste != [] and Enum.all?(liste, &MapSet.member?(sel, &1.id)))
  end

  defp date_fr(nil), do: "—"
  defp date_fr(d), do: Calendar.strftime(d, "%d/%m/%Y")
end
