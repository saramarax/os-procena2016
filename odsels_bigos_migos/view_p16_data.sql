--------------------------------------------------------
--  DDL for View P16_DATA
--------------------------------------------------------

  CREATE OR REPLACE VIEW P16_DATA AS
  select count(*) over () cnt, x6."RBR",x6."ID_NOM",x6."NAZIV_NOMENKLATURE",x6."PERIOD",x6."KONTO",x6."KONTO_NAZIV",x6."ID_OS",x6."NAZIV_SREDSTVA",x6."OJ",x6."OJ_NAZIV",x6."KOLICINA",x6."JED_MERE",x6."DATUM_NABAVKE",x6."DATUM_AKTIVIRANJA",x6."DATUM_DEAKTIVIRANJA",x6."KLASA_SIFRA",x6."KLASA_NAZIV",x6."AMORT_GRUPA_SIFRA",x6."AMORT_GRUPA_NAZIV",x6."AMORT_STOPA",x6."EKONOMSKI_VEK_UPOTREBE",x6."PREOSTALI_VEK_31_DEC_2015",x6."REZIDUALNA",x6."NABAVNA_VREDNOST",x6."OTPISANA_VREDNOST",x6."SADASNJA_VREDNOST",x6."KONTO_EFEKATA",x6."EFEKAT_PROCENE",x6."KONTO_UMANJENJA",x6."UMANJENJE_PROCENA",x6."DONACIJA",x6."PROCENAT_DONACIJA",x6."TIP",x6."RBR2",x6."AMORT_JAN",x6."TROSAK",x6."PREOSTALI_VEK_TRAJANJA",x6."KONTO_REV_REZERVI",x6."KONTO_UMANJENJA2",x6."KJ32_02390",x6."KJ33_582",x6."KJ34_682",x6."KJ35_330",x6."KJ36_498",x6."J1_NAB_31JAN",x6."J2_ISP_31JAN",x6."J3_SAD_31JAN",x6."J4_UMANJENJE",x6."J5_REV_REZ_OLD",x6."J5_REV_REZ",x6."J6",x6."J14_P_NAB",x6."J15_P_ISP",x6."J16_P_SAD",x6."J17_P_REZID",x6."J18_P_PREOST_VEK",x6."J12_AMORT_11_MES",x6."J19_AMORT_11_MES",x6."J20",x6."J21_POVEC_SAD",x6."J26_SMANJENJE_SAD",x6."J22_UKIDANJE_UMANJENJA",x6."J28_UKIDANJE_REV_REZ",x6."J23_POVECANJE_REV_REZ",x6."J27_POVECANJE_UMANJENJA",x6."J24_KONTR_NULA",x6."J29_KONTR_NULA",x6."J30",x6."J31_EFF_NA_NAB_02300_D",x6."J32_EFF_NA_ISP_02390_P",x6."J33_EFF_NA_UMANJ_58202_D",x6."J34_EFF_NA_GASENJE_UM_68202_P",x6."J35_EFF_NA_REV_REZ_33004_P",x6."J36_EF_NA_ODL_POROB_RR_49800_P",x6."J37_EF_PREKNAUMANJ_02390_P",x6."J38_EF_PREKSAISP_NA_UM_02398_P",x6."ID_VRSTA_PROMENE"
   from(
         select x5.*, j21_povec_sad-j22_ukidanje_umanjenja-j23_povecanje_rev_rez j24_kontr_nula
            , j26_smanjenje_sad-j27_povecanje_umanjenja-j28_ukidanje_rev_rez j29_kontr_nula
            , case when substr(x5.konto,1,3)='022' then 2 else 1 end j30
            , j14_p_nab-j1_nab_31jan j31_eff_na_nab_02300_d
            , j15_p_isp - j2_isp_31jan j32_eff_na_isp_02390_p
            , j27_povecanje_umanjenja j33_eff_na_umanj_58202_d
            , j22_ukidanje_umanjenja j34_eff_na_gasenje_um_68202_p
            --j35=j23-j28-j36
            , j23_povecanje_rev_rez-j28_ukidanje_rev_rez-case when j4_umanjenje=0 and j5_rev_rez=0 then 0 else round(j23_povecanje_rev_rez*0.15,2) end j35_eff_na_rev_rez_33004_p
            --j36= if j4=0 and j5=0 then 0 else j23*0.1 end if
            , case when j4_umanjenje=0 and j5_rev_rez=0 then 0 else round(j23_povecanje_rev_rez*0.15,2) end j36_ef_na_odl_porob_rr_49800_p
            --j37=-j38
            , -1*(j27_povecanje_umanjenja-j22_ukidanje_umanjenja) j37_ef_preknaumanj_02390_p
            --j38=j33-j34
            , j27_povecanje_umanjenja-j22_ukidanje_umanjenja j38_ef_preksaisp_na_um_02398_p
            , case when j21_povec_sad > 0
              then case when j5_rev_rez > 0
                       then 150
                       else case when j4_umanjenje > 0
                                then case when j4_umanjenje > j21_povec_sad
                                         then 151
                                         else 152
                                     end
                                else 153
                            end
                       end
              else case when j26_smanjenje_sad > 0
                       then case when j4_umanjenje > 0
                                then 160
                                else case when j5_rev_rez > 0
                                         then case when j5_rev_rez > j26_smanjenje_sad
                                                  then 162
                                                  else 161
                                              end
                                         else 163
                                     end
                                end
                       else 0
                   end
          end id_vrsta_promene

      from(
            select x4.*, case when j21_povec_sad>j22_ukidanje_umanjenja then j21_povec_sad-j22_ukidanje_umanjenja else 0 end j23_povecanje_rev_rez
                  , case when j26_smanjenje_sad>j28_ukidanje_rev_rez then j26_smanjenje_sad-j28_ukidanje_rev_rez else 0 end j27_povecanje_umanjenja
            from (
                  select x3.* , case when j4_umanjenje>0 then case when j21_povec_sad>j4_umanjenje then j4_umanjenje else j21_povec_sad end  else 0 end j22_ukidanje_umanjenja
                        , case when j26_smanjenje_sad>0 then case when j26_smanjenje_sad>j5_rev_rez then j5_rev_rez else j26_smanjenje_sad end else 0 end j28_ukidanje_rev_rez
                  from (
                        select x2.*, case when j16_p_sad>j3_sad_31jan then j16_p_sad-j3_sad_31jan else 0 end j21_povec_sad
                              , case when j3_sad_31jan>j16_p_sad then j3_sad_31jan-j16_p_sad else 0 end j26_smanjenje_sad
                        from (
                              select x1.* , x1.nabavna_vrednost j1_nab_31jan, x1.amort_jan j2_isp_31jan, x1.nabavna_vrednost-x1.amort_jan j3_sad_31jan
                                 , nvl(x1.umanjenje_procena,0) j4_umanjenje, nvl(x1.efekat_procene,0) j5_rev_rez_old, round((nvl(x1.efekat_procene,0)/85)*100,2) j5_rev_rez , '' j6, p_vred_zamenskog_os j14_p_nab, p_vred_zamenskog_os-p_fer j15_p_isp, p_fer j16_p_sad
                                 , p_rezidualna j17_p_rezid, p_preostali_vek j18_p_preost_vek, p_iznos_amort j12_amort_11_mes
                                 , case when p_preostali_vek=0 then 0 else round(((p_fer-p_rezidualna)/p_preostali_vek)*(11/12),2) end j19_amort_11_mes, '' j20
                              from (
                                    select x.*
                                       ,nvl((select otpisana from k where id_osnovna_sredstva=x.id_os and id_vrsta_promene=169),0) amort_jan
                                       , (select trosak from o where id_osnovna_sredstva=x.id_os) trosak
                                       , (select preostali_vek_trajanja from o where id_osnovna_sredstva=x.id_os) preostali_vek_trajanja
                                       , (select proc_rev_rez_x from os_knjizenje where period=7 and id_vp=111 and oj=x.oj and konto3=substr(x.konto,1,3)) konto_rev_rezervi
                                       , (select proc_smanjenje_y from os_knjizenje where period=7 and id_vp=111 and oj=x.oj and konto3=substr(x.konto,1,3)) konto_umanjenja2
                                       , (select kj32_02390 from p16_sema_knjizenja where konto3=substr(x.konto,1,3)) kj32_02390
                                       , (select kj33_582 from p16_sema_knjizenja where konto3=substr(x.konto,1,3)) kj33_582
                                       , (select kj34_682 from p16_sema_knjizenja where konto3=substr(x.konto,1,3)) kj34_682
                                       , (select kj35_330 from p16_sema_knjizenja where konto3=substr(x.konto,1,3)) kj35_330
                                       , (select kj36_498 from p16_sema_knjizenja where konto3=substr(x.konto,1,3)) kj36_498
                                    from p16_all x
                                    where exists (select 1 from pr16_data where id_os=x.id_os)
--                                    and oj not in (10,17,2,20)
                                    and not exists (select 1 from os_osnovna_sredstva where datum_zatvaranja>'31-dec-2015' and id_osnovna_sredstva=x.id_os)
                                    )x1, pr16_data p
                              where x1.id_os=p.id_os
                              )x2
                        )x3
                  )x4
            )x5
      )x6
      where id_vrsta_promene<>0;
