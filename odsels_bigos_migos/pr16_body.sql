create or replace PACKAGE BODY "PR16" as

procedure procena as
   cursor c1 is --1327 rows
   select * from(
   select d.*, o.preostali_vek_trajanja, o.period, o.trosak, o.nabavna_vrednost, o.nabavna_vrednost + d.poz_eff_na_nab_d + d.neg_eff_na_nab_d nab,  o.otpisana_vrednost
   , o.otpisana_vrednost + d.poz_eff_na_isp_p + d.neg_eff_na_isp_p otp
   , o.nabavna_vrednost + d.poz_eff_na_nab_d + d.neg_eff_na_nab_d -(o.otpisana_vrednost + d.poz_eff_na_isp_p + d.neg_eff_na_isp_p) sad
   , j14_p_nab, j15_p_isp, j16_p_sad, x.id_vrsta_promene, x.j31_eff_na_nab_02300_d, d.poz_eff_na_nab_d+d.neg_eff_na_nab_d, x.j32_eff_na_isp_02390_p, d.poz_eff_na_isp_p+d.neg_eff_na_isp_p
   , case when nvl(d.poz_eff_na_nab_d,0)<>0 or nvl(d.poz_eff_na_isp_p,0)<>0  then -- povecanje
         case when nvl(d.poz_gasenje_um_d,0)<>0 then --postojalo umanjenje
                  case when nvl(d.poz_eff_na_rev_rez_p,0)<>0 then 152 else 151 end
              else case when nvl(s.efekat_procene,0) <> 0 then 150 else 153 end
         end
      when nvl(neg_eff_na_nab_d,0)<>0 or nvl(neg_eff_na_isp_p,0)<>0 then --smanjenje
         case when nvl(neg_gasenje_rev_rez_d,0)<>0 then --postojale rev rez
                  case when nvl(neg_form_umanj_p,0)<>0 then 161 else 162 end
              else case when nvl(s.umanjenje_procena,0)<>0 then 160 else 163 end
         end
      else 0 end id_vp
      , (select proc_smanjenje_y from os_knjizenje where period=7 and id_vp=111 and oj=d.oj and konto3=substr(d.konto,1,3)) konto_umanjenja
      from pr16_data d, os_osnovna_sredstva o, p16_data x, p16_all s
      where d.otudjeno<>1
      and d.id_os=o.id_osnovna_sredstva
      and d.id_os=s.id_os
      and d.id_os=x.id_os(+)
   --   and procenjuje_se='DA'
      order by sad
   )where id_vp<>0;

   v_id_kartice os_kartica.id_kartica%type;
  begin

    for r in c1 loop
      update os_osnovna_sredstva o
         set o.nabavna_vrednost = o.nabavna_vrednost + r.poz_eff_na_nab_d + r.neg_eff_na_nab_d,
             o.otpisana_vrednost = o.otpisana_vrednost + r.poz_eff_na_isp_p + r.neg_eff_na_isp_p,
             o.rezidualna = r.rezidual
       where o.id_osnovna_sredstva = r.id_os;

      v_id_kartice := seq_os_kartica.nextval;
      insert into os_kartica
      values
        (v_id_kartice, r.poz_eff_na_isp_p + r.neg_eff_na_isp_p, r.poz_eff_na_nab_d + r.neg_eff_na_nab_d, sysdate, g_datum_obracuna, 150 --r.id_vrsta_promene
        , r.id_os, null, 'PROC2016', null, g_radnik_id, 0, null, r.period, r.konto, r.oj, r.trosak);
      --sacuvaj trenutni preostali vek
      insert into os_preostali_vek values (v_id_kartice, r.preostali_vek_trajanja);
      --dodeli novi vek osnovnom sredstvu
      update os_osnovna_sredstva o
         set o.preostali_vek_trajanja = r.preostali_vek
       where o.id_osnovna_sredstva = r.id_os;

       if(nvl(r.poz_eff_na_nab_d,0)+nvl(r.neg_eff_na_nab_d,0) <> 0) then
         util.insert_os_nalog_fip(nvl(r.poz_eff_na_nab_d,0)+nvl(r.neg_eff_na_nab_d,0), 0, g_datum_obracuna, v_id_kartice, r.id_vp, r.period,  nvl(r.poz_kon_eff_na_nab_d,r.neg_kon_eff_na_nab_d)||0, g_radnik_id, null);
       end if;

       if(nvl(r.poz_eff_na_isp_p,0)-nvl(r.neg_eff_na_isp_p,0) <> 0) then
         util.insert_os_nalog_fip(0, nvl(r.poz_eff_na_isp_p,0)+nvl(r.neg_eff_na_isp_p,0), g_datum_obracuna, v_id_kartice, r.id_vp, r.period,  nvl(r.poz_kon_eff_na_isp_p,r.neg_kon_eff_na_isp_p)||0, g_radnik_id, null);
       end if;

        --zavisno od vrste promene...
      case r.id_vp
        when 150 then
          --povecanje-postoje rev rezerve koje rastu
           insert into os_efekat_procene values
            (seq_os_efekat_procene.nextval, v_id_kartice, 0, r.poz_eff_na_rev_rez_p, r.period, r.poz_kon_eff_na_rev_rez_p||'0', r.id_os, null, 'P');

           util.insert_os_nalog_fip(0, r.poz_eff_na_rev_rez_p, g_datum_obracuna, v_id_kartice, 150, r.period,  r.poz_kon_eff_na_rev_rez_p||'0', g_radnik_id, null);

        when 151 then
          --povecanje-postoji umanjenje koje opada
          insert into os_efekat_procene values
            (seq_os_efekat_procene.nextval, v_id_kartice, r.poz_gasenje_um_d, 0, r.period, r.konto_umanjenja, r.id_os, null, 'S');

          util.insert_os_nalog_fip(r.poz_gasenje_um_d, 0, g_datum_obracuna, v_id_kartice, 151, r.period,  r.konto_umanjenja, g_radnik_id, null);
          util.insert_os_nalog_fip(0, r.poz_gasenje_um_p, g_datum_obracuna, v_id_kartice, 151, r.period,  r.poz_kon_gasenje_um_p||'0', g_radnik_id, null);

          if(nvl(r.poz_korist_isp_p,0)<>0) then
            util.insert_os_nalog_fip(0, r.poz_korist_isp_p, g_datum_obracuna, v_id_kartice, 151, r.period,  r.poz_kon_korist_isp_p||'0', g_radnik_id, null);
          end if;

          if(nvl(r.poz_korist_eff_p,0)<>0) then
            util.insert_os_nalog_fip(0, r.poz_korist_eff_p, g_datum_obracuna, v_id_kartice, 151, r.period,  r.poz_kon_korist_eff_p||'0', g_radnik_id, null);
          end if;

        when 152 then
          --povecanje-postojece umanjenje se ponistava i prelazi se na povecanje rev rezervi
          insert into os_efekat_procene values
            (seq_os_efekat_procene.nextval, v_id_kartice, r.poz_gasenje_um_d, 0, r.period, r.konto_umanjenja, r.id_os, null, 'S');

          insert into os_efekat_procene values
            (seq_os_efekat_procene.nextval, v_id_kartice, 0, r.poz_eff_na_rev_rez_p, r.period, r.poz_kon_eff_na_rev_rez_p||'0', r.id_os, null, 'P');

            util.insert_os_nalog_fip(r.poz_gasenje_um_d, 0, g_datum_obracuna, v_id_kartice, 152, r.period,  r.konto_umanjenja, g_radnik_id, null);
            util.insert_os_nalog_fip(0, r.poz_gasenje_um_p, g_datum_obracuna, v_id_kartice, 152, r.period,  r.poz_kon_gasenje_um_p||'0', g_radnik_id, null);

            util.insert_os_nalog_fip(0, r.poz_eff_na_rev_rez_p, g_datum_obracuna, v_id_kartice, 152, r.period,  r.poz_kon_eff_na_rev_rez_p||'0', g_radnik_id, null);

            if nvl(r.poz_korist_isp_p,0) <> 0 then
               util.insert_os_nalog_fip(0, r.poz_korist_isp_p, g_datum_obracuna, v_id_kartice, 152, r.period,  r.poz_kon_korist_isp_p||'0', g_radnik_id, null);
            end if;

            if(nvl(r.poz_korist_eff_p,0)<>0) then
               util.insert_os_nalog_fip(0, r.poz_korist_eff_p, g_datum_obracuna, v_id_kartice, 152, r.period,  r.poz_kon_korist_eff_p||'0', g_radnik_id, null);
            end if;
        when 153 then
          --povecanje-nisu postojale rev rezerve
          insert into os_efekat_procene values
            (seq_os_efekat_procene.nextval, v_id_kartice, 0, r.poz_eff_na_rev_rez_p, r.period, r.poz_kon_eff_na_rev_rez_p||'0', r.id_os, null, 'P');

            util.insert_os_nalog_fip(0, r.poz_eff_na_rev_rez_p, g_datum_obracuna, v_id_kartice, 153, r.period,  r.poz_kon_eff_na_rev_rez_p||'0', g_radnik_id, null);

        when 160 then
          --smanjenje-postojalo umanjenje koje se povecava
          insert into os_efekat_procene values
            (seq_os_efekat_procene.nextval, v_id_kartice, 0, r.neg_form_umanj_p, r.period, r.konto_umanjenja, r.id_os, null, 'S');

            util.insert_os_nalog_fip(0, r.neg_form_umanj_p, g_datum_obracuna, v_id_kartice, 160, r.period,  r.konto_umanjenja, g_radnik_id, null);

            util.insert_os_nalog_fip(r.neg_rash_um_d, 0, g_datum_obracuna, v_id_kartice, 160, r.period,  r.neg_kon_rash_um_d||'0', g_radnik_id, null);

            if(nvl(r.neg_form_isp_d,0)<>0) then
               util.insert_os_nalog_fip(r.neg_form_isp_d, 0, g_datum_obracuna, v_id_kartice, 160, r.period,  r.neg_kon_form_isp_d||'0', g_radnik_id, null);
            end if;

            if nvl(r.neg_form_eff_proc_d,0)<>0 then
               util.insert_os_nalog_fip(r.neg_form_eff_proc_d, 0, g_datum_obracuna, v_id_kartice, 160, r.period,  r.neg_kon_form_eff_proc_d||'0', g_radnik_id, null);
            end if;

        when 161 then
          --smanjenje-postojale rev rezerve koje se ponistavaju i prelaze u umanjenje
          insert into os_efekat_procene values
            (seq_os_efekat_procene.nextval, v_id_kartice, r.neg_gasenje_rev_rez_d, 0, r.period, r.neg_kon_gasenje_rev_rez_d||'0', r.id_os, null, 'P');
          insert into os_efekat_procene values
            (seq_os_efekat_procene.nextval, v_id_kartice, 0, r.neg_form_umanj_p, r.period, r.konto_umanjenja, r.id_os, null, 'S');

            util.insert_os_nalog_fip(r.neg_gasenje_rev_rez_d, 0, g_datum_obracuna, v_id_kartice, 161, r.period,  r.neg_kon_gasenje_rev_rez_d||'0', g_radnik_id, null);

            util.insert_os_nalog_fip(0, r.neg_form_umanj_p, g_datum_obracuna, v_id_kartice, 161, r.period,  r.konto_umanjenja, g_radnik_id, null);

            util.insert_os_nalog_fip(r.neg_rash_um_d, 0, g_datum_obracuna, v_id_kartice, 161, r.period,  r.neg_kon_rash_um_d||'0', g_radnik_id, null);

             if(nvl(r.neg_form_isp_d,0)<>0) then
               util.insert_os_nalog_fip(r.neg_form_isp_d, 0, g_datum_obracuna, v_id_kartice, 161, r.period,  r.neg_kon_form_isp_d||'0', g_radnik_id, null);
            end if;

            if nvl(r.neg_form_eff_proc_d,0)<>0 then
               util.insert_os_nalog_fip(r.neg_form_eff_proc_d, 0, g_datum_obracuna, v_id_kartice, 161, r.period,  r.neg_kon_form_eff_proc_d||'0', g_radnik_id, null);
            end if;

        when 162 then
          --smanjenje-postojale rev rezerve koje se smanjuju
          insert into os_efekat_procene values
            (seq_os_efekat_procene.nextval, v_id_kartice, r.neg_gasenje_rev_rez_d, 0, r.period, r.neg_kon_gasenje_rev_rez_d||'0', r.id_os, null, 'P');

            util.insert_os_nalog_fip(r.neg_gasenje_rev_rez_d, 0, g_datum_obracuna, v_id_kartice, 162, r.period,  r.neg_kon_gasenje_rev_rez_d||'0', g_radnik_id, null);

        when 163 then
          --smanjenje-nije postojalo umanjenje po proceni
          insert into os_efekat_procene values
            (seq_os_efekat_procene.nextval, v_id_kartice, 0, r.neg_form_umanj_p, r.period, r.konto_umanjenja, r.id_os, null, 'S');

            util.insert_os_nalog_fip(0, r.neg_form_umanj_p, g_datum_obracuna, v_id_kartice, 163, r.period,  r.konto_umanjenja, g_radnik_id, null);

            util.insert_os_nalog_fip(r.neg_rash_um_d, 0, g_datum_obracuna, v_id_kartice, 163, r.period,  r.neg_kon_rash_um_d||'0', g_radnik_id, null);

            if(nvl(r.neg_form_isp_d,0)<>0) then
               util.insert_os_nalog_fip(r.neg_form_isp_d, 0, g_datum_obracuna, v_id_kartice, 163, r.period,  r.neg_kon_form_isp_d||'0', g_radnik_id, null);
            end if;

            if nvl(r.neg_form_eff_proc_d,0)<>0 then
               util.insert_os_nalog_fip(r.neg_form_eff_proc_d, 0, g_datum_obracuna, v_id_kartice, 163, r.period,  r.neg_kon_form_eff_proc_d||'0', g_radnik_id, null);
            end if;

        else
          raise_application_error('-20038', 'Za osnovno sredstvo idos=' || r.id_os);
      end case; --case


    end loop;

    commit;

    exception
      when others then
        rollback;
        raise;
  end procena;
--------------------------------------------------------------------------------
procedure delete_procena is
  cursor c1 is
   select * from k where napomena='PROC2016';
begin
   for r in c1 loop
      update os_osnovna_sredstva
      set nabavna_vrednost = nabavna_vrednost - r.nabavna
         , otpisana_vrednost = otpisana_vrednost - r.otpisana
         , preostali_vek_trajanja=(select preostali_vek from os_preostali_vek where id_kartica = r.id_kartica)
      where id_osnovna_sredstva=r.id_osnovna_sredstva;

      delete from os_preostali_vek where id_kartica=r.id_kartica;

      delete from os_efekat_procene where id_kartica = r.id_kartica;
      --delete from stavke and nalog
      delete from stavke where (godina#, organizaciona_jedinica#, vrsta_naloga#, broj_naloga#) in
               (select distinct godina, organizaciona_jedinica, vrsta_naloga, broj_naloga
                  from os_nalog_fip where id_os_kartice=r.id_kartica);

      delete from nalog where (godina#, organizaciona_jedinica#, vrsta_naloga#, broj_naloga#) in
               (select distinct godina, organizaciona_jedinica, vrsta_naloga, broj_naloga
                  from os_nalog_fip where id_os_kartice=r.id_kartica);

      delete from os_nalog_fip where id_os_kartice = r.id_kartica;

      delete from os_kartica where id_kartica=r.id_kartica;
   end loop;
   commit;
exception
when others then
   rollback;
   dbms_output.put_line (sqlcode||'-'||sqlerrm) ;
   raise;
end delete_procena;
--------------------------------------------------------------------------------
procedure korekcija_naloga(p_datum date, p_napomena varchar2) is
cursor c1 (v_napomena varchar2) is
select n.organizaciona_jedinica oj, sum(iznos_duguje)-sum(iznos_potrazuje) razl
from os_nalog_fip n where id_os_kartice in (select id_kartica from os_kartica k where id_kartica=n.id_os_kartice and k.napomena=v_napomena)
group by n.organizaciona_jedinica
having sum(iznos_duguje)-sum(iznos_potrazuje)<>0
order by razl;

k_row os_kartica%rowtype;

begin
   for r in c1(p_napomena) loop
      if r.razl < 0 then
         select *
         into k_row
         from(
            select * from k where id_kartica in (
            select id_os_kartice
            from os_nalog_fip n
            where id_os_kartice in (
                  select id_kartica from os_kartica k where id_kartica=n.id_os_kartice and k.napomena=p_napomena and k.organizaciona_jedinica=r.oj
                  )
            group by id_os_kartice
            having sum(iznos_duguje)<sum(iznos_potrazuje)
         ))where rownum=1;

         util.insert_os_nalog_fip(-r.razl, 0, p_datum, k_row.id_kartica, k_row.id_vrsta_promene, k_row.period, '559900', g_radnik_id, null);
      else
         select *
         into k_row
         from(
            select * from k where id_kartica in (
            select id_os_kartice
            from os_nalog_fip n
            where id_os_kartice in (
                  select id_kartica from os_kartica k where id_kartica=n.id_os_kartice and k.napomena=p_napomena and k.organizaciona_jedinica=r.oj
                  )
            group by id_os_kartice
            having sum(iznos_duguje)>sum(iznos_potrazuje)
         ))where rownum=1;

         util.insert_os_nalog_fip(0, r.razl, p_datum, k_row.id_kartica, k_row.id_vrsta_promene, k_row.period, '659090', g_radnik_id, null);
      end if;
   end loop;

   commit;
   exception
     when others then
       rollback;
       raise;
end korekcija_naloga;
--------------------------------------------------------------------------------
procedure uvec_rev_rez is
   cursor c1 is --4001 rows
   select d.* , s.konto konto_os, s.period, o.trosak
   from pr16_data d, p16_all s, o
   where nvl(uvec_rev_rez_p,0)<>0 and otudjeno<>1
   and d.id_os=s.id_os
   and d.id_os=o.id_osnovna_sredstva
   and d.uvec_rev_rez_kon_p is not null;

   v_id_kartice os_kartica.id_kartica%type;
begin
   for r in c1 loop
      v_id_kartice := seq_os_kartica.nextval;

      insert into os_kartica values
      (v_id_kartice, 0, 0, sysdate, g_datum_obracuna, 170, r.id_os, null, 'PROC2016-povecanje eff procene pre procene', null, g_radnik_id, 0, null, r.period, r.konto_os, r.oj, r.trosak);

      insert into os_efekat_procene values
      (seq_os_efekat_procene.nextval, v_id_kartice, 0, r.uvec_rev_rez_p, r.period, r.uvec_rev_rez_kon_p||'0',r.id_os, null, 'P');

      util.insert_os_nalog_fip(0, r.uvec_rev_rez_p, g_datum_obracuna, v_id_kartice, 170, r.period,  r.uvec_rev_rez_kon_p||'0', g_radnik_id, null);
      util.insert_os_nalog_fip(r.uvec_rev_rez_d, 0, g_datum_obracuna, v_id_kartice, 170, r.period,  r.uvec_rev_rez_kon_d||'0', g_radnik_id, null);
   end loop;

   commit;
   exception
   when others then
      rollback;
      dbms_output.put_line (sqlcode||'-'||sqlerrm) ;
      raise;
end uvec_rev_rez;
--------------------------------------------------------------------------------
procedure delete_uvec_rev_rez is
cursor c1 is
select * from k where napomena like 'PROC2016-povecanje eff procene pre procene';
begin
   for r in c1 loop
      delete from os_efekat_procene where id_kartica = r.id_kartica;
      --delete from stavke and nalog
      delete from stavke where (godina#, organizaciona_jedinica#, vrsta_naloga#, broj_naloga#) in
               (select distinct godina, organizaciona_jedinica, vrsta_naloga, broj_naloga
                  from os_nalog_fip where id_os_kartice=r.id_kartica);

      delete from nalog where (godina#, organizaciona_jedinica#, vrsta_naloga#, broj_naloga#) in
               (select distinct godina, organizaciona_jedinica, vrsta_naloga, broj_naloga
                  from os_nalog_fip where id_os_kartice=r.id_kartica);

      delete from os_nalog_fip where id_os_kartice = r.id_kartica;

      delete from os_kartica where id_kartica=r.id_kartica;
   end loop;

   commit;
exception
when others then
   rollback;
   dbms_output.put_line (sqlcode||'-'||sqlerrm) ;
   raise;
end delete_uvec_rev_rez;
--------------------------------------------------------------------------------
procedure obr_amort_11_mes(p_oj number) is

--ovaj cursor nije dobar on treba da ide za sva os koja su bila na proceni a konto <> 020 i 021
cursor c1 (v_oj number)is --916 rows
select k.* --count(*) over() cnt, q.*, k.otpisana
from(
   select d.*, o.preostali_vek_trajanja, o.period, o.trosak, o.nabavna_vrednost, o.nabavna_vrednost + d.poz_eff_na_nab_d + d.neg_eff_na_nab_d nab,  o.otpisana_vrednost
   , o.otpisana_vrednost + d.poz_eff_na_isp_p + d.neg_eff_na_isp_p otp
   , o.nabavna_vrednost + d.poz_eff_na_nab_d + d.neg_eff_na_nab_d -(o.otpisana_vrednost + d.poz_eff_na_isp_p + d.neg_eff_na_isp_p) sad
   , j14_p_nab, j15_p_isp, j16_p_sad, x.id_vrsta_promene, x.j31_eff_na_nab_02300_d, d.poz_eff_na_nab_d+d.neg_eff_na_nab_d, x.j32_eff_na_isp_02390_p, d.poz_eff_na_isp_p+d.neg_eff_na_isp_p
   , case when nvl(d.poz_eff_na_nab_d,0)<>0 or nvl(d.poz_eff_na_isp_p,0)<>0  then -- povecanje
         case when nvl(d.poz_gasenje_um_d,0)<>0 then --postojalo umanjenje
                  case when nvl(d.poz_eff_na_rev_rez_p,0)<>0 then 152 else 151 end
              else case when nvl(s.efekat_procene,0) <> 0 then 150 else 153 end
         end
      when nvl(neg_eff_na_nab_d,0)<>0 or nvl(neg_eff_na_isp_p,0)<>0 then --smanjenje
         case when nvl(neg_gasenje_rev_rez_d,0)<>0 then --postojale rev rez
                  case when nvl(neg_form_umanj_p,0)<>0 then 161 else 162 end
              else case when nvl(s.umanjenje_procena,0)<>0 then 160 else 163 end
         end
      else 0 end id_vp
      , (select proc_smanjenje_y from os_knjizenje where period=7 and id_vp=111 and oj=d.oj and konto3=substr(d.konto,1,3)) konto_umanjenja
      from pr16_data d, os_osnovna_sredstva o, p16_data x, p16_all s
      where d.otudjeno<>1
      and d.id_os=o.id_osnovna_sredstva
      and d.id_os=s.id_os
      and d.id_os=x.id_os(+)
      and d.oj=v_oj
   --   and procenjuje_se='DA'
      order by sad
   )q, k
   where id_vp<>0
   and q.id_os=k.id_osnovna_sredstva
   and  k.id_vrsta_promene=110
   and k.datum_promene='31-dec-2016'
--   and k.otpisana<> 0
   and (amort_p<>0 or k.otpisana<>0)
--   and k.id_status is null
   ;

cursor c2 (p_id_kart number)is
select n.*
from k, os_nalog_fip n, os_knjizenje knj
where k.id_kartica=n.id_os_kartice
and k.period=knj.period
and substr(k.konto,1,3)=knj.konto3
and n.organizaciona_jedinica=knj.oj
and knj.id_vp=110
--and (n.konto = knj.ispravka_i or n.konto=knj.amort_god_h)
and k.id_kartica=p_id_kart;

   v_id_obracuna number (10) ;
   v_datum_od date := to_date('01.02.2016','dd.mm.yyyy');
   v_mesec_obracuna number (2) ;
   v_tip_amortizacije os_obracun_amortizacije.tip_amortizacije%type;
   v_napomena varchar2(255):= 'obracum amort 11 mes za procenjena os';
   l_os_tab os_amort.t_osn_sre_tab;
   l_os os_amort.t_osn_sre;
   l_id_stavka_amort os_stavka_amortizacije.id_stavka_amortizacije%type;
   l_id_kartica os_kartica.id_kartica%type;
   l_id_stavka_amort_donac os_stavka_amortizacije_donac.id_stavka_amortizacije_donac%type;
   v_vrsta_promene number :=110;
   v_amort_dec2016 os_kartica.otpisana%type;
   v_old_kart os_kartica%rowtype;
   v_id_kartica os_kartica.id_kartica%type;
begin

   v_tip_amortizacije := 3;

   v_id_obracuna := seq_os_obracun_amortizacije.nextval;
   v_mesec_obracuna := to_number (to_char (g_datum_amort, 'mm')) ;

   insert into os_obracun_amortizacije values
      ( v_id_obracuna, v_napomena, v_datum_od, g_datum_amort, v_tip_amortizacije, g_datum_amort, p_oj, g_radnik_id, 'F' ) ;

   for r in c1(p_oj) loop

      begin
            select *
            into v_old_kart
            from os_kartica
            where napomena='konacan dec 2016' and datum_promene='31-dec-2016' and id_vrsta_promene=110 and id_status is null and id_osnovna_sredstva=r.id_osnovna_sredstva;

            if v_old_kart.otpisana<>0 then--storniraj staru amortizaciju
               select seq_os_kartica.nextval into v_id_kartica from dual;

               insert into os_kartica values
               (v_id_kartica, v_old_kart.otpisana, 0, sysdate, g_datum_amort, 210, v_old_kart.id_osnovna_sredstva, 3, 'storno amortizacije za 11 meseci 2016', null, g_radnik_id, 0, null, v_old_kart.period, v_old_kart.konto, v_old_kart.organizaciona_jedinica, v_old_kart.trosak);

               update os_kartica set id_status=3 where id_kartica=v_old_kart.id_kartica;

               delete from os_kartica_donac where id_kartica_os=v_old_kart.id_kartica;

               update os_osnovna_sredstva set otpisana_vrednost = otpisana_vrednost - v_old_kart.otpisana where id_osnovna_sredstva=v_old_kart.id_osnovna_sredstva;

               for n in c2(v_old_kart.id_kartica) loop
                  insert into os_nalog_fip values
                  (n.godina, n.organizaciona_jedinica, null, 210, n.period, n.konto, n.poslovna_jedinica_tros, n.trosak, -1*n.iznos_duguje, -1*n.iznos_potrazuje, null, null, sysdate, n.vrsta_naloga, null, v_id_kartica, seq_os_nalog_fip.nextval, g_radnik_id, null, n.ogranak, n.pogon, n.poslovnica, n.delatnost_pd);
               end loop;
            end if;
            exception
            when no_data_found then
            null;
      end;
      l_os_tab.delete;

      os_amort.popuna_os_tab (l_os_tab, v_datum_od, g_datum_amort, p_oj, r.id_osnovna_sredstva) ;

      if (l_os_tab.count = 0) then
         raise_application_error ('-20002', 'id_os='|| '1911111114' ||'nije pronadjen') ;
      end if;

      for i in 1..l_os_tab.count
      loop
         --      dbms_output.put_line (l_os_tab (i) .id_os || ':' || l_os_tab (i) .iznos_amort) ;
         l_os := l_os_tab (i) ;
         insert
         into test_amort values
            (
               l_os.id_os, l_os.stopa_amort, l_os.iznos_amort, l_os.donac_iznos_amort, l_os.poreska_iznos_amort
            ) ;

         l_id_stavka_amort := seq_os_stavka_amortizacije.nextval;

         insert into os_stavka_amortizacije values
            (l_id_stavka_amort, l_os.iznos_amort, v_id_obracuna, l_os.id_os, l_os.stopa_amort, 'F') ;

         l_id_stavka_amort_donac := seq_os_stavka_amort_donac.nextval;

         insert into os_stavka_amortizacije_donac values
            (l_id_stavka_amort_donac, l_os.donac_iznos_amort, v_id_obracuna, l_os.id_os, l_os.stopa_amort, l_id_stavka_amort) ;

         l_id_kartica := seq_os_kartica.nextval;

         insert into os_kartica values (
               l_id_kartica, l_os.iznos_amort, 0, sysdate, g_datum_amort, v_vrsta_promene, l_os.id_os, null, v_napomena, l_id_stavka_amort,
               g_radnik_id, 0, null, l_os.period, l_os.konto, p_oj, l_os.trosak ) ;

         if (l_os.donac_iznos_amort <> 0) then
            insert into os_kartica_donac values
               ( seq_os_kartica_donac.nextval, 0, l_os.donac_iznos_amort, g_datum_amort, g_datum_amort, v_vrsta_promene, l_os.id_os, null,
                  v_napomena, l_id_stavka_amort_donac, g_radnik_id, sysdate, l_id_kartica ) ;
         end if;

         update os_osnovna_sredstva
         set otpisana_vrednost = otpisana_vrednost + l_os.iznos_amort
         where id_osnovna_sredstva = l_os.id_os;

      end loop;
   end loop;

      --insert into os_nalog_fip stavka1
      insert into os_nalog_fip
      select to_number (to_char (b.datum_obracuna, 'yyyy')) godina, b.organizaciona_jedinica, null, v_vrsta_promene, m.period, m.ispravka_i, decode (nvl
         (p.indikator_sifarnika, 0), 2, o.organizaciona_jedinica, null) organizaciona_jedinica, decode (nvl (p.indikator_sifarnika, 0), 2, nvl (o.trosak
         , '999992'), null) trosak, 0, s.iznos, null, null, sysdate, 11, null, k.id_kartica, seq_os_nalog_fip.nextval, g_radnik_id,
         s.id_obracun_amortizacije, o.ogranak, o.pogon, o.poslovnica, o.delatnost_pd
      from os_stavka_amortizacije s, os_obracun_amortizacije b, os_osnovna_sredstva o, os_kartica k, os_knjizenje m, kontni_plan p
      where s.id_obracun_amortizacije = b.id_obracun_amortizacije
      and s.id_osnovna_sredstva = o.id_osnovna_sredstva
      and s.id_stavka_amortizacije = k.id_stavka_amortizacije
      and o.period = m.period
      and substr (o.konto, 1, 3) = m.konto3
      and m.id_vp = v_vrsta_promene
      and m.oj = p_oj
      and m.period = p.period
      and m.ispravka_i = p.konto
      and m.datum_do is null
      and s.iznos <> 0
      and s.id_obracun_amortizacije = v_id_obracuna;

      --insert into os_nalog_fip stavka2
      insert into os_nalog_fip
      select to_number (to_char (b.datum_obracuna, 'yyyy')) godina, b.organizaciona_jedinica, null, v_vrsta_promene, m.period, m.amort_god_h, decode (
         nvl (p.indikator_sifarnika, 0), 2, o.organizaciona_jedinica, null) organizaciona_jedinica, decode (nvl (p.indikator_sifarnika, 0), 2, nvl (
         o.trosak, '999992'), null) trosak, s.iznos, 0, null, null, sysdate, 11, null, k.id_kartica, seq_os_nalog_fip.nextval, g_radnik_id,
         s.id_obracun_amortizacije, o.ogranak, o.pogon, o.poslovnica, o.delatnost_pd
      from os_stavka_amortizacije s, os_obracun_amortizacije b, os_osnovna_sredstva o, os_kartica k, os_knjizenje m, kontni_plan p
      where s.id_obracun_amortizacije = b.id_obracun_amortizacije
      and s.id_osnovna_sredstva = o.id_osnovna_sredstva
      and s.id_stavka_amortizacije = k.id_stavka_amortizacije
      and o.period = m.period
      and substr (o.konto, 1, 3) = m.konto3
      and m.id_vp = v_vrsta_promene
      and m.oj = p_oj
      and m.period = p.period
      and m.amort_god_h = p.konto
      and m.datum_do is null
      and s.iznos <> 0
      and s.id_obracun_amortizacije = v_id_obracuna;

--insert into os_nalog_fip stavka donacija1
   insert into os_nalog_fip
   select to_number (to_char (b.datum_obracuna, 'yyyy')) godina, b.organizaciona_jedinica, null, v_vrsta_promene, m.period, m.amort_donac_a, decode (
      nvl (p.indikator_sifarnika, 0), 2, o.organizaciona_jedinica, null) organizaciona_jedinica, decode (nvl (p.indikator_sifarnika, 0), 2, nvl (
      o.trosak, '999992'), null) trosak, 0, d.iznos, null, null, sysdate, 11, null, k.id_kartica, seq_os_nalog_fip.nextval, g_radnik_id,
      s.id_obracun_amortizacije, o.ogranak, o.pogon, o.poslovnica, o.delatnost_pd
   from os_stavka_amortizacije_donac d, os_stavka_amortizacije s, os_obracun_amortizacije b, os_osnovna_sredstva o, os_kartica k, os_knjizenje m,
      kontni_plan p
   where d.id_stavka_amortizacije = s.id_stavka_amortizacije
   and s.id_obracun_amortizacije = b.id_obracun_amortizacije
   and s.id_osnovna_sredstva = o.id_osnovna_sredstva
   and s.id_stavka_amortizacije = k.id_stavka_amortizacije
   and o.period = m.period
   and substr (o.konto, 1, 3) = m.konto3
   and m.id_vp = v_vrsta_promene
   and m.oj = p_oj
   and m.period = p.period
   and m.amort_donac_a = p.konto
   and m.datum_do is null
   and d.iznos <> 0
   and s.id_obracun_amortizacije = v_id_obracuna;

   --insert into os_nalog_fip stavka donacija2
   insert into os_nalog_fip
   select to_number (to_char (b.datum_obracuna, 'yyyy')) godina, b.organizaciona_jedinica, null, v_vrsta_promene, m.period, m.donacija_isp_g, decode
      (nvl (p.indikator_sifarnika, 0), 2, o.organizaciona_jedinica, null) organizaciona_jedinica, decode (nvl (p.indikator_sifarnika, 0), 2, nvl (
      o.trosak, '999992'), null) trosak, d.iznos, 0, null, null, sysdate, 11, null, k.id_kartica, seq_os_nalog_fip.nextval, g_radnik_id,
      s.id_obracun_amortizacije, o.ogranak, o.pogon, o.poslovnica, o.delatnost_pd
   from os_stavka_amortizacije_donac d, os_stavka_amortizacije s, os_obracun_amortizacije b, os_osnovna_sredstva o, os_kartica k, os_knjizenje m,
      kontni_plan p
   where d.id_stavka_amortizacije = s.id_stavka_amortizacije
   and s.id_obracun_amortizacije = b.id_obracun_amortizacije
   and s.id_osnovna_sredstva = o.id_osnovna_sredstva
   and s.id_stavka_amortizacije = k.id_stavka_amortizacije
   and o.period = m.period
   and substr (o.konto, 1, 3) = m.konto3
   and m.id_vp = v_vrsta_promene
   and m.oj = p_oj
   and m.period = p.period
   and m.donacija_isp_g = p.konto
   and m.datum_do is null
   and d.iznos <> 0
   and s.id_obracun_amortizacije = v_id_obracuna;

   commit;
exception
when others then
   rollback;
   raise;
end obr_amort_11_mes;
--------------------------------------------------------------------------------
end pr16;
/
