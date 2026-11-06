defmodule Garage.RechercheTest do
  use ExUnit.Case, async: true

  alias Garage.Recherche

  describe "normaliser/1" do
    test "retire les accents" do
      assert Recherche.normaliser("Benoît") == "benoit"
      assert Recherche.normaliser("Lefèvre") == "lefevre"
      assert Recherche.normaliser("Citroën") == "citroen"
      assert Recherche.normaliser("THÔNES") == "thones"
    end

    test "remplace la ponctuation par une espace" do
      assert Recherche.normaliser("Jean-Pierre") == "jean pierre"
      assert Recherche.normaliser("AB-123-CD") == "ab 123 cd"
    end

    test "conserve les chiffres" do
      assert Recherche.normaliser("0612345678") == "0612345678"
    end

    test "tolère nil et le vide" do
      assert Recherche.normaliser(nil) == ""
      assert Recherche.normaliser("   ") == ""
    end
  end

  describe "index/1" do
    test "produit les deux formes, espacée et compactée" do
      index = Recherche.index(["AB-123-CD"])

      assert index =~ "ab 123 cd"
      assert index =~ "ab123cd"
    end

    test "ne duplique pas quand les deux formes coïncident" do
      assert Recherche.index(["Renault"]) == "renault"
    end

    test "ignore les valeurs vides" do
      assert Recherche.index([nil, "", "Dupont"]) == "dupont"
    end
  end
end
