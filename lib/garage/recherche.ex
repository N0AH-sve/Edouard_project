defmodule Garage.Recherche do
  @moduledoc """
  Normalisation des textes pour la recherche.

  SQLite ne sait comparer que l'ASCII : `LOWER('Benoît')` rend `benoît`,
  et chercher « benoit » ne trouve rien. Or personne ne tape les accents
  dans une barre de recherche.

  On stocke donc, à côté des vraies données, une forme aplatie — sans
  accent, en minuscules, sans ponctuation — et c'est elle qu'on
  interroge. Les données affichées, elles, gardent leurs accents.
  """

  @doc """
  « Benoît Lefèvre » → « benoit lefevre »

  Les chiffres sont conservés (téléphones, plaques), la ponctuation
  devient une espace, et les espaces multiples sont réduits.
  """
  @spec normaliser(String.t() | nil) :: String.t()
  def normaliser(nil), do: ""

  def normaliser(texte) when is_binary(texte) do
    texte
    |> :unicode.characters_to_nfd_binary()
    # Retire les diacritiques laissés par la décomposition NFD.
    |> String.replace(~r/[\x{0300}-\x{036F}]/u, "")
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/u, " ")
    |> String.trim()
  end

  @doc """
  Assemble plusieurs champs en une seule chaîne interrogeable.

  Chaque valeur est indexée deux fois : espacée et compactée. Sans la
  forme compactée, « AB-123-CD » deviendrait « ab 123 cd » et la
  recherche « ab123cd » — la façon naturelle de taper une plaque —
  ne trouverait rien.
  """
  @spec index([String.t() | nil]) :: String.t()
  def index(valeurs) do
    valeurs
    |> Enum.flat_map(fn valeur ->
      espace = normaliser(valeur)
      compact = String.replace(espace, " ", "")

      cond do
        espace == "" -> []
        espace == compact -> [espace]
        true -> [espace, compact]
      end
    end)
    |> Enum.uniq()
    |> Enum.join(" ")
  end
end
