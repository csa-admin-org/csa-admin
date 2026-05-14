# frozen_string_literal: true

require "test_helper"

class DeliveryPDFTest < ActiveSupport::TestCase
  test "format_member_name_for_pdf: full_name returns name unchanged" do
    org = Current.org
    org.delivery_pdf_member_name_format = "none"

    assert_equal "Jean Dupont",       org.format_member_name_for_pdf("Jean Dupont")
    assert_equal "Arias Emmanuelle",  org.format_member_name_for_pdf("Arias Emmanuelle")
    assert_equal "Bob",               org.format_member_name_for_pdf("Bob")
    assert_equal "Anne van Koesveld", org.format_member_name_for_pdf("Anne van Koesveld")
  end

  test "format_member_name_for_pdf: abbreviate_last — standard First Last" do
    org = Current.org
    org.delivery_pdf_member_name_format = "abbreviate_last"

    assert_equal "Jean D.",  org.format_member_name_for_pdf("Jean Dupont")
    assert_equal "Marie B.", org.format_member_name_for_pdf("Marie Bernard")
    assert_equal "Anna M.",  org.format_member_name_for_pdf("Anna Meyer-Weitkamp")
  end

  test "format_member_name_for_pdf: abbreviate_last — name with particles" do
    org = Current.org
    org.delivery_pdf_member_name_format = "abbreviate_last"

    assert_equal "Anne van K.",       org.format_member_name_for_pdf("Anne van Koesveld")
    assert_equal "Ilona van der K.",  org.format_member_name_for_pdf("Ilona van der Kroef")
    assert_equal "David de V.",       org.format_member_name_for_pdf("David de Vries")
    assert_equal "Daan Wilms van K.", org.format_member_name_for_pdf("Daan Wilms van Kersbergen")
  end

  test "format_member_name_for_pdf: abbreviate_last — single word unchanged" do
    org = Current.org
    org.delivery_pdf_member_name_format = "abbreviate_last"

    assert_equal "Bob",  org.format_member_name_for_pdf("Bob")
    assert_equal "Ruud", org.format_member_name_for_pdf("Ruud")
  end

  test "format_member_name_for_pdf: abbreviate_last — multi-person comma" do
    org = Current.org
    org.delivery_pdf_member_name_format = "abbreviate_last"

    assert_equal "Grit L., Jonas L.",            org.format_member_name_for_pdf("Grit Liebelt, Jonas Liebelt")
    assert_equal "Caroline B., Perrin M.",       org.format_member_name_for_pdf("Caroline Bourrit, Perrin Manuel")
    assert_equal "Lisa R., Robert G., Paula W.", org.format_member_name_for_pdf("Lisa Reul, Robert Gruhne, Paula Willert")
  end

  test "format_member_name_for_pdf: abbreviate_last — multi-person conjunctions" do
    org = Current.org
    org.delivery_pdf_member_name_format = "abbreviate_last"

    assert_equal "Caroline B. und Frank C.", org.format_member_name_for_pdf("Caroline Böttcher und Frank Cüper")
    assert_equal "Frans en Janine F.",       org.format_member_name_for_pdf("Frans en Janine Faber")
    assert_equal "Maarten B. & Sacha R.",    org.format_member_name_for_pdf("Maarten Both & Sacha Roché")
    assert_equal "Jean D. et Marie M.",      org.format_member_name_for_pdf("Jean Dupont et Marie Martin")
  end

  test "format_member_name_for_pdf: abbreviate_last — last single-word segment is abbreviated" do
    org = Current.org
    org.delivery_pdf_member_name_format = "abbreviate_last"

    # Last segment abbreviated even when it's a single word
    assert_equal "Langer, N.", org.format_member_name_for_pdf("Langer, Nadine")
    assert_equal "Bruns, H.",  org.format_member_name_for_pdf("Bruns, Hille")
    # Non-last single-word segments are left alone
    assert_equal "Bob, Jean D.", org.format_member_name_for_pdf("Bob, Jean Dupont")
  end

  test "format_member_name_for_pdf: abbreviate_first — standard Last First" do
    org = Current.org
    org.delivery_pdf_member_name_format = "abbreviate_first"

    assert_equal "A. Emmanuelle", org.format_member_name_for_pdf("Arias Emmanuelle")
    assert_equal "B. Cyril",      org.format_member_name_for_pdf("Babando Cyril")
    assert_equal "B. Laurent",    org.format_member_name_for_pdf("Ballmer Laurent")
    assert_equal "B. Séverine",   org.format_member_name_for_pdf("Bertschi Séverine")
  end

  test "format_member_name_for_pdf: abbreviate_first — single word unchanged" do
    org = Current.org
    org.delivery_pdf_member_name_format = "abbreviate_first"

    assert_equal "Bob",  org.format_member_name_for_pdf("Bob")
  end

  test "format_member_name_for_pdf: abbreviate_first — multi-person comma" do
    org = Current.org
    org.delivery_pdf_member_name_format = "abbreviate_first"

    assert_equal "A. Caroline & N. Manuel", org.format_member_name_for_pdf("Arizzi Caroline & Nicolas Manuel")
    assert_equal "B. Caroline & P. Manuel", org.format_member_name_for_pdf("Bourrit Caroline & Perrin Manuel")
  end

  test "format_member_name_for_pdf: abbreviate_first — first single-word segment is abbreviated" do
    org = Current.org
    org.delivery_pdf_member_name_format = "abbreviate_first"

    # First segment abbreviated even when it's a single word
    assert_equal "L., Nadine",   org.format_member_name_for_pdf("Langer, Nadine")
    assert_equal "P., Ellen",    org.format_member_name_for_pdf("Philipp, Ellen")
    # Non-first single-word segments are left alone
    assert_equal "J. Dupont, Bob", org.format_member_name_for_pdf("Jean Dupont, Bob")
  end

  test "format_member_name_for_pdf: initials — standard names" do
    org = Current.org
    org.delivery_pdf_member_name_format = "initials"

    assert_equal "J. D.",       org.format_member_name_for_pdf("Jean Dupont")
    assert_equal "A. E.",       org.format_member_name_for_pdf("Arias Emmanuelle")
    assert_equal "A. v. K.",    org.format_member_name_for_pdf("Anne van Koesveld")
    assert_equal "I. v. d. K.", org.format_member_name_for_pdf("Ilona van der Kroef")
    assert_equal "A. M.",       org.format_member_name_for_pdf("Anna Meyer-Weitkamp")
  end

  test "format_member_name_for_pdf: initials — single word unchanged" do
    org = Current.org
    org.delivery_pdf_member_name_format = "initials"

    assert_equal "Bob",  org.format_member_name_for_pdf("Bob")
  end

  test "format_member_name_for_pdf: initials — multi-person" do
    org = Current.org
    org.delivery_pdf_member_name_format = "initials"

    assert_equal "G. L., J. L.",    org.format_member_name_for_pdf("Grit Liebelt, Jonas Liebelt")
    assert_equal "C. B. und F. C.", org.format_member_name_for_pdf("Caroline Böttcher und Frank Cüper")
    assert_equal "M. B. & S. R.",   org.format_member_name_for_pdf("Maarten Both & Sacha Roché")
    # Single-word segments in a multi-person name are abbreviated too
    assert_equal "B., H.",          org.format_member_name_for_pdf("Bruns, Hille")
  end
end
