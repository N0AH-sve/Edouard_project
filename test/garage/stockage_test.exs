defmodule Garage.StockageTest do
  use ExUnit.Case, async: true

  alias Garage.Fichiers
  alias Garage.Stockage

  setup do
    File.mkdir_p!(Stockage.racine())
    :ok
  end

  defp fichier_temporaire(contenu) do
    chemin = Path.join(System.tmp_dir!(), "essai-#{System.unique_integer([:positive])}")
    File.write!(chemin, contenu)
    on_exit(fn -> File.rm(chemin) end)
    chemin
  end

  test "enregistre un PDF et renvoie ses métadonnées" do
    source = fichier_temporaire(Fichiers.pdf())

    assert {:ok, infos} = Stockage.enregistrer(source, "facture.pdf")

    assert infos.nom == "facture.pdf"
    assert infos.content_type == "application/pdf"
    assert infos.taille > 0
    assert File.exists?(Stockage.chemin_absolu(infos.chemin))

    Stockage.supprimer(infos.chemin)
  end

  test "le chemin stocké est relatif et ne contient pas le nom d'origine" do
    source = fichier_temporaire(Fichiers.pdf())

    assert {:ok, infos} = Stockage.enregistrer(source, "facture.pdf")

    refute String.starts_with?(infos.chemin, "/")
    refute infos.chemin =~ "facture"
    assert infos.chemin =~ ~r"^\d{4}/[0-9a-f-]+\.pdf$"

    Stockage.supprimer(infos.chemin)
  end

  test "un nom de fichier malveillant ne sort pas du dossier" do
    source = fichier_temporaire(Fichiers.pdf())

    assert {:ok, infos} = Stockage.enregistrer(source, "../../../etc/passwd.pdf")

    # Le nom affiché est réduit au nom de base, et le chemin réel est
    # généré par nous : rien n'est écrit ailleurs.
    assert infos.nom == "passwd.pdf"

    absolu = Stockage.chemin_absolu(infos.chemin)
    assert String.starts_with?(Path.expand(absolu), Path.expand(Stockage.racine()))

    Stockage.supprimer(infos.chemin)
  end

  test "refuse un fichier qui n'est pas un vrai PDF" do
    source = fichier_temporaire(Fichiers.faux_pdf())
    assert {:error, :pas_un_pdf} = Stockage.enregistrer(source, "piege.pdf")
  end

  test "refuse un fichier vide" do
    source = fichier_temporaire("")
    assert {:error, :pas_un_pdf} = Stockage.enregistrer(source, "vide.pdf")
  end

  test "un nom vide reçoit un nom par défaut" do
    source = fichier_temporaire(Fichiers.pdf())
    assert {:ok, infos} = Stockage.enregistrer(source, "   ")
    assert infos.nom == "document.pdf"
    Stockage.supprimer(infos.chemin)
  end

  test "supprimer/1 tolère un fichier déjà absent" do
    assert Stockage.supprimer("2026/inexistant.pdf") == :ok
  end
end
