defmodule GarageWeb.Composants.Documents do
  @moduledoc """
  Bloc « Documents » : dépôt de PDF, liste, consultation, suppression.

  Partagé par les fiches client, véhicule et intervention. Le
  rattachement est passé en attribut, sous la forme `{:client, id}`.
  """
  use GarageWeb, :live_component

  alias Garage.Atelier
  alias Garage.Stockage

  @max_fichiers 10

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign(:documents, Atelier.list_documents(assigns.rattachement))
      |> autoriser_depot()

    {:ok, socket}
  end

  # `allow_upload/3` ne doit être appelé qu'une fois : `update/2` est
  # rejoué à chaque rafraîchissement du parent.
  defp autoriser_depot(socket) do
    if Map.get(socket.assigns, :depot_pret) do
      socket
    else
      socket
      |> allow_upload(:pdf,
        accept: ~w(.pdf application/pdf),
        max_entries: @max_fichiers,
        max_file_size: Stockage.taille_max(),
        auto_upload: false
      )
      |> assign(:depot_pret, true)
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section class="space-y-3">
      <div class="flex items-baseline justify-between">
        <h2 class="font-semibold">
          Documents
          <span class="ml-1 rounded-full bg-base-200 px-2 py-0.5 text-xs text-base-content/60">
            {length(@documents)}
          </span>
        </h2>
        <p class="text-xs text-base-content/50">
          PDF uniquement, {Float.round(Stockage.taille_max() / 1_048_576, 0) |> trunc()} Mo maximum
        </p>
      </div>

      <form
        id={"depot-#{@id}"}
        phx-target={@myself}
        phx-change="valider_depot"
        phx-submit="televerser"
        phx-drop-target={@uploads.pdf.ref}
        class="rounded-xl border border-dashed border-base-300 bg-base-200/40 px-4 py-5 text-center"
      >
        <.icon name="hero-document-arrow-up" class="mx-auto size-7 text-base-content/30" />

        <p class="mt-2 text-sm">
          <label
            for={@uploads.pdf.ref}
            class="cursor-pointer font-semibold text-primary hover:underline"
          >
            Choisir des fichiers
          </label>
          <span class="text-base-content/50"> ou les glisser ici</span>
        </p>

        <.live_file_input upload={@uploads.pdf} class="sr-only" />

        <%!-- Fichiers en attente d'envoi --%>
        <ul :if={@uploads.pdf.entries != []} class="mt-4 space-y-2 text-left">
          <li
            :for={entree <- @uploads.pdf.entries}
            class="flex items-center gap-3 rounded-lg bg-white px-3 py-2"
          >
            <.icon name="hero-document" class="size-4 shrink-0 text-base-content/40" />
            <span class="min-w-0 flex-1 truncate text-sm">{entree.client_name}</span>

            <span class="text-xs tabular-nums text-base-content/50">{entree.progress}&nbsp;%</span>

            <button
              type="button"
              phx-target={@myself}
              phx-click="retirer_entree"
              phx-value-ref={entree.ref}
              title="Retirer"
              class="grid size-6 place-items-center rounded-full text-base-content/40 hover:bg-base-200 hover:text-error"
            >
              <.icon name="hero-x-mark" class="size-4" />
            </button>
          </li>
        </ul>

        <%!-- Erreurs signalées par LiveView avant même l'envoi --%>
        <p
          :for={erreur <- erreurs_globales(@uploads.pdf)}
          class="mt-2 text-sm text-error"
        >
          {message_erreur(erreur)}
        </p>
        <p
          :for={{entree, erreur} <- erreurs_par_fichier(@uploads.pdf)}
          class="mt-2 text-sm text-error"
        >
          {entree.client_name} : {message_erreur(erreur)}
        </p>

        <button
          :if={@uploads.pdf.entries != []}
          type="submit"
          phx-disable-with="Envoi…"
          class="mt-4 rounded-full bg-primary px-5 py-2 text-sm font-semibold text-primary-content transition hover:bg-secondary"
        >
          Archiver {length(@uploads.pdf.entries)} fichier{if length(@uploads.pdf.entries) > 1,
            do: "s"}
        </button>
      </form>

      <%!-- Documents déjà archivés --%>
      <ul :if={@documents != []} class="divide-y divide-base-300 rounded-xl border border-base-300">
        <li :for={document <- @documents} class="flex items-center gap-3 px-4 py-3">
          <.icon name="hero-document-text" class="size-5 shrink-0 text-error/70" />

          <div class="min-w-0 flex-1">
            <a
              href={~p"/documents/#{document}"}
              target="_blank"
              rel="noopener"
              class="block truncate text-sm font-medium hover:text-primary hover:underline"
            >
              {document.nom}
            </a>
            <p class="text-xs text-base-content/50">
              {Garage.Atelier.Document.taille_lisible(document.taille)} · ajouté le {date_fr(
                document.inserted_at
              )}
            </p>
          </div>

          <a
            href={~p"/documents/#{document}/telecharger"}
            title="Télécharger"
            class="grid size-8 place-items-center rounded-full text-base-content/40 hover:bg-base-200 hover:text-base-content"
          >
            <.icon name="hero-arrow-down-tray" class="size-4" />
          </a>

          <button
            type="button"
            phx-target={@myself}
            phx-click="supprimer"
            phx-value-id={document.id}
            data-confirm={"Supprimer définitivement « #{document.nom} » ?"}
            title="Supprimer"
            class="grid size-8 place-items-center rounded-full text-base-content/40 hover:bg-error/10 hover:text-error"
          >
            <.icon name="hero-trash" class="size-4" />
          </button>
        </li>
      </ul>
    </section>
    """
  end

  @impl true
  def handle_event("valider_depot", _params, socket) do
    # La validation est faite par LiveView ; ce gestionnaire existe pour
    # que les erreurs et la progression soient rendues.
    {:noreply, socket}
  end

  def handle_event("retirer_entree", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :pdf, ref)}
  end

  def handle_event("televerser", _params, socket) do
    resultats =
      consume_uploaded_entries(socket, :pdf, fn %{path: chemin}, entree ->
        {:ok, Atelier.archiver_pdf(chemin, entree.client_name, socket.assigns.rattachement)}
      end)

    {reussis, echecs} = Enum.split_with(resultats, &match?({:ok, _}, &1))

    annoncer(length(reussis), echecs)

    {:noreply, assign(socket, :documents, Atelier.list_documents(socket.assigns.rattachement))}
  end

  def handle_event("supprimer", %{"id" => id}, socket) do
    document = Atelier.get_document!(id)
    {:ok, _} = Atelier.supprimer_document(document)

    send(self(), {:message_documents, :info, "Document supprimé."})

    {:noreply, assign(socket, :documents, Atelier.list_documents(socket.assigns.rattachement))}
  end

  # Un LiveComponent ne pose pas de message flash lui-même : il prévient
  # la vue parente, qui possède le flash.
  defp annoncer(n, echecs) do
    if n > 0 do
      send(self(), {:message_documents, :info, "#{n} document#{s(n)} archivé#{s(n)}."})
    end

    if echecs != [] do
      send(
        self(),
        {:message_documents, :error, Enum.map_join(echecs, " ", &message_echec/1)}
      )
    end
  end

  defp message_echec({:error, :pas_un_pdf}),
    do: "Un fichier a été refusé : ce n'est pas un vrai PDF malgré son extension."

  defp message_echec({:error, :trop_gros}), do: "Un fichier dépasse la taille autorisée."
  defp message_echec({:error, :fichier_vide}), do: "Un fichier est vide."
  defp message_echec({:error, _}), do: "Un fichier n'a pas pu être archivé."

  defp s(n) when n > 1, do: "s"
  defp s(_), do: ""

  defp erreurs_globales(upload) do
    Enum.flat_map(upload.errors, fn
      {ref, erreur} when ref == upload.ref -> [erreur]
      _ -> []
    end)
  end

  defp erreurs_par_fichier(upload) do
    Enum.flat_map(upload.entries, fn entree ->
      Enum.map(upload_errors(upload, entree), &{entree, &1})
    end)
  end

  defp message_erreur(:too_large), do: "fichier trop volumineux"
  defp message_erreur(:too_many_files), do: "trop de fichiers à la fois (10 maximum)"
  defp message_erreur(:not_accepted), do: "seuls les fichiers PDF sont acceptés"
  defp message_erreur(:external_client_failure), do: "l'envoi a échoué"
  defp message_erreur(_), do: "fichier refusé"

  defp date_fr(%DateTime{} = d), do: Calendar.strftime(d, "%d/%m/%Y")
  defp date_fr(_), do: "—"
end
