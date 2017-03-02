create or replace PACKAGE "PR16"
as
  g_datum_obracuna DATE := to_date('31.01.2016', 'dd.mm.yyyy');
  g_datum_amort DATE := to_date('31.12.2016', 'dd.mm.yyyy');
  g_radnik_id      NUMBER(6, 0) := 999901;
  g_tekuca_godina  NUMBER(4, 0) := 2011;
  g_vn_11          NUMBER := 11;
   procedure procena;
   procedure delete_procena;
   procedure korekcija_naloga(p_datum date, p_napomena varchar2);
   procedure uvec_rev_rez;
   procedure delete_uvec_rev_rez;

  procedure obr_amort_11_mes(p_oj number);
end pr16;
/
