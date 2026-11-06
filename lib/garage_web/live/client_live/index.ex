defmodule GarageWeb.ClientLive.Index do
  @moduledoc "Tableau principal : la liste des clients du garage."
  use GarageWeb, :live_view

  alias Garage.Atelier
  alias Garage.Atelier.Client

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      reglages={@reglages}
      titre="Clients"
      actif={:clients}
      recherche={@recherche}
      placeholder_recherche="Nom, téléphone, immatriculation…"
    >
      <:onglets>
        <Layouts.onglet navigate={~p"/clients"} icone="hero-users" actif compteur={@total}>
          Tous les clients
        </Layouts.onglet>
      </:onglets>

      <:actions>
        <p :if={@recherche != ""} class="mr-auto text-sm text-base-content/60">
          {length(@clients)} résultat{if length(@clients) > 1, do: "s"} pour
          <span class="font-medium text-base-content">« {@recherche} »</span>
        </p>

        <.link
          navigate={~p"/clients/nouveau"}
          class="inline-flex items-center gap-2 rounded-full bg-primary px-5 py-2.5 text-sm font-semibold text-primary-content transition hover:bg-secondary"
        >
          <.icon name="hero-plus" class="size-4" /> Nouveau client
        </.link>
      </:actions>

      <div :if={@clients == []} class="px-6 py-16 text-center">
        <.icon name="hero-users" class="mx-auto size-10 text-base-content/20" />
        <p class="mt-4 font-medium">
          {if @recherche == "", do: "Aucun client pour le moment.", else: "Aucun résultat."}
        </p>
        <p class="mt-1 text-sm text-base-content/60">
          {if @recherche == "",
            do: "Créez votre première fiche client pour démarrer.",
            else: "Essayez un autre nom, un téléphone ou une immatriculation."}
        </p>
      </div>

      <div :if={@clients != []} class="overflow-x-auto">
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
              <th>Nom</th>
              <th>Téléphone</th>
              <th>Ville</th>
              <th>Véhicules</th>
              <th class="w-12"></th>
            </tr>
          </thead>
          <tbody>
            <tr
              :for={client <- @clients}
              class={[selectionne?(@selection, client.id) && "ligne-selectionnee"]}
            >
              <td class="pl-5">
                <input
                  type="checkbox"
                  class="checkbox checkbox-sm checkbox-primary"
                  checked={selectionne?(@selection, client.id)}
                  phx-click="basculer"
                  phx-value-id={client.id}
                  aria-label={"Sélectionner #{Client.nom_complet(client)}"}
                />
              </td>

              <td>
                <.link
                  navigate={~p"/clients/#{client}"}
                  class="font-medium hover:text-primary hover:underline"
                >
                  {Client.nom_complet(client)}
                </.link>
                <p :if={client.email} class="text-xs text-base-content/50">{client.email}</p>
              </td>

              <td class="tabular-nums">{telephone(client.telephone)}</td>

              <td>
                <span :if={client.ville}>{client.ville}</span>
                <span :if={!client.ville} class="text-base-content/30">—</span>
              </td>

              <td>
                <span :if={client.vehicules == []} class="pastille pastille-neutre">aucun</span>
                <span :if={client.vehicules != []} class="flex flex-wrap gap-1">
                  <.link
                    :for={v <- client.vehicules}
                    navigate={~p"/vehicules/#{v}"}
                    class="rounded-md bg-base-200 px-2 py-0.5 font-mono text-xs hover:bg-primary/10 hover:text-primary"
                  >
                    {v.immatriculation}
                  </.link>
                </span>
              </td>

              <td class="pr-5 text-right">
                <.link
                  navigate={~p"/clients/#{client}/modifier"}
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
        <Layouts.bouton_barre phx-click="exporter">
          <.icon name="hero-arrow-down-tray" class="size-4" /> Exporter
        </Layouts.bouton_barre>
        <Layouts.bouton_barre
          danger
          phx-click="supprimer_selection"
          data-confirm="Supprimer définitivement les clients sélectionnés ?"
        >
          <.icon name="hero-trash" class="size-4" /> Supprimer
        </Layouts.bouton_barre>
      </Layouts.barre_selection>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Clients")
     |> assign(:recherche, "")
     |> assign(:selection, MapSet.new())
     |> charger()}
  end

  @impl true
  def handle_event("rechercher", %{"q" => q}, socket) do
    # La sélection est vidée : garder cochées des lignes devenues
    # invisibles conduirait à supprimer sans voir quoi.
    {:noreply,
     socket
     |> assign(:recherche, q)
     |> assign(:selection, MapSet.new())
     |> charger()}
  end

  def handle_event("basculer", %{"id" => id}, socket) do
    id = String.to_integer(id)

    selection =
      if MapSet.member?(socket.assigns.selection, id),
        do: MapSet.delete(socket.assigns.selection, id),
        else: MapSet.put(socket.assigns.selection, id)

    {:noreply, assign_selection(socket, selection)}
  end

  def handle_event("basculer_tout", _params, socket) do
    selection =
      if socket.assigns.tout_coche,
        do: MapSet.new(),
        else: MapSet.new(socket.assigns.clients, & &1.id)

    {:noreply, assign_selection(socket, selection)}
  end

  def handle_event("tout_deselectionner", _params, socket) do
    {:noreply, assign_selection(socket, MapSet.new())}
  end

  def handle_event("exporter", _params, socket) do
    {:noreply, put_flash(socket, :info, "L'export arrive bientôt — rien n'a été modifié.")}
  end

  def handle_event("supprimer_selection", _params, socket) do
    {supprimes, refuses} =
      socket.assigns.selection
      |> Enum.map(&Atelier.get_client!/1)
      |> Enum.split_with(fn client ->
        match?({:ok, _}, Atelier.delete_client(client))
      end)

    socket =
      socket
      |> assign(:selection, MapSet.new())
      |> charger()
      |> message_suppression(length(supprimes), refuses)

    {:noreply, socket}
  end

  defp message_suppression(socket, 0, refuses) do
    put_flash(socket, :error, texte_refus(refuses))
  end

  defp message_suppression(socket, n, []) do
    put_flash(socket, :info, "#{n} client#{pluriel(n)} supprimé#{pluriel(n)}.")
  end

  defp message_suppression(socket, n, refuses) do
    socket
    |> put_flash(:info, "#{n} client#{pluriel(n)} supprimé#{pluriel(n)}.")
    |> put_flash(:error, texte_refus(refuses))
  end

  # Un client qui possède encore un véhicule n'est pas supprimable : la
  # base refuse, pour ne pas effacer un historique au passage.
  defp texte_refus(refuses) do
    noms = Enum.map_join(refuses, ", ", &Client.nom_complet/1)
    n = length(refuses)

    "#{n} client#{pluriel(n)} conservé#{pluriel(n)} (#{noms}) : " <>
      "supprimez d'abord leurs véhicules."
  end

  defp pluriel(n) when n > 1, do: "s"
  defp pluriel(_), do: ""

  defp assign_selection(socket, selection) do
    socket
    |> assign(:selection, selection)
    |> calculer_tout_coche()
  end

  defp charger(socket) do
    clients = Atelier.list_clients(recherche: socket.assigns.recherche)

    socket
    |> assign(:clients, clients)
    |> assign(:total, Atelier.count_clients())
    |> calculer_tout_coche()
  end

  defp calculer_tout_coche(socket) do
    clients = socket.assigns[:clients] || []
    selection = socket.assigns.selection

    tout =
      clients != [] and Enum.all?(clients, &MapSet.member?(selection, &1.id))

    assign(socket, :tout_coche, tout)
  end

  defp selectionne?(selection, id), do: MapSet.member?(selection, id)

  # 0612345678 → 06 12 34 56 78
  defp telephone(nil), do: "—"

  defp telephone(numero) do
    case String.length(numero) do
      10 ->
        numero |> String.graphemes() |> Enum.chunk_every(2) |> Enum.map_join(" ", &Enum.join/1)

      _ ->
        numero
    end
  end
end
