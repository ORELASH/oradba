
השאילתה של פקיד : 


create view public.vw_pakid_online_459_details
            (taatich_avoda, taarich_nohehi, bank, snif, tat_snif, tahana, emda, taz_pakid, pakid_mevatzea,
             dwhinsertdate, name, userid, cellular, workcellular, jobname, onlineorder)
as
SELECT a.taarich_nohehi                                                                                                               AS taatich_avoda,
       a.taarich_nohehi,
       a.bank,
       a.snif,
       a.tat_snif,
       a.tahana,
       a.emda,
       a.taz_pakid,
       a.pakid_mevatzea,
       a.dwhinsertdate,
       b.name,
       b.userid,
       b.cellular,
       b.workcellular,
       b.jobname,
       row_number()
       OVER (PARTITION BY a.bank, a.snif, a.tat_snif, a.tahana, a.emda, a.taz_pakid, a.pakid_mevatzea ORDER BY a.taarich_nohehi DESC) AS onlineorder
FROM dim_pakid_online_459 a
         LEFT JOIN dimifpersons2_432 b ON a.taz_pakid = b.personid::bigint;


create table public.dim_pakid_online_459
(
    taarich_avoda      date,
    taarich_nohehi     timestamp,
    bank               smallint,
    snif               smallint,
    tat_snif           smallint,
    tahana             smallint,
    emda               varchar(2),
    taz_pakid          bigint,
    pakid_mevatzea     integer,
    dwhinsertdate      timestamp,
    sourcetable        varchar(20),
    dwhcloudinsertdate timestamp default timezone('Asia/Jerusalem'::text, now()) not null
);


השאילתה של סניף : 



create table public.dimsnif_303
(
    snifkey            smallint                                                  not null,
    snifbukey          varchar(9),
    banknumber         smallint,
    snifnumber         smallint,
    snifnameheb        varchar(20),
    snifnameeng        varchar(25),
    snifcityheb        varchar(14),
    snifstreetheb      varchar(25),
    snifaddressheb     varchar(40),
    snifaddresseng     varchar(50),
    zipcode            varchar(5),
    phonenumber        varchar(10),
    faxnumber          varchar(10),
    sugsnif            smallint,
    merchav            smallint,
    bankfullnameheb    varchar(30),
    bankfullnameeng    varchar(30),
    bankshortnameheb   varchar(10),
    bankshortnameeng   varchar(10),
    rashaymatach       smallint,
    rashaymati         smallint,
    rashhamara         smallint,
    rashsnfachr        smallint,
    rashaynemesh       smallint,
    rashaymaof         smallint,
    rashayswift        smallint,
    mokedlean          smallint,
    opendate           timestamp,
    closedate          timestamp,
    riind              smallint                                                  not null,
    dwhsource          varchar(50)                                               not null,
    dwhinsertdate      timestamp                                                 not null,
    dwhupdatedate      timestamp,
    dwhcloudinsertdate timestamp default timezone('Asia/Jerusalem'::text, now()) not null
);


create table public.ref_menahelsnif
(
    id                 integer,
    refdate            timestamp,
    snif_no            integer,
    expirationdate     varchar(20),
    taz                bigint,
    lastname           varchar(50),
    firstname          varchar(50),
    kartis             varchar(50),
    other              varchar(50),
    dwhinsertdate      timestamp,
    dwhcloudinsertdate timestamp default timezone('Asia/Jerusalem'::text, now()) not null
);


create table public.dimifpersons2_432
(
    id                     integer                                                   not null,
    creator                varchar(50),
    fromdate               timestamp                                                 not null,
    created                timestamp                                                 not null,
    modified               timestamp                                                 not null,
    rowchecksum            varchar(50)                                               not null,
    envid                  integer                                                   not null,
    systemid               varchar(250)                                              not null,
    objectid               varchar(250)                                              not null,
    type                   varchar(250)                                              not null,
    pernr                  varchar(250),
    personid               varchar(250),
    name                   varchar(100),
    startdate              timestamp,
    ezor                   varchar(250),
    ttez                   varchar(250),
    actiontype             varchar(250),
    userid                 varchar(250),
    groupid                integer,
    org                    varchar(250),
    mail                   varchar(250),
    ugr                    varchar(250),
    mol                    varchar(250),
    wlc                    varchar(250),
    lomed                  varchar(250),
    bsisi                  varchar(250),
    menhl                  varchar(250),
    mnhlliba               varchar(250),
    lomedliba              varchar(250),
    grouptype              varchar(250),
    lock                   varchar(250),
    employeestatus         integer,
    action                 integer,
    enddate                timestamp,
    changedate             timestamp,
    firstnameeng           varchar(250),
    lastnameeng            varchar(250),
    cardnumber             varchar(250),
    subgroup               integer,
    plans                  varchar(250),
    stell                  varchar(250),
    sessionid              varchar(250),
    ezorname               varchar(250),
    ttezname               varchar(250),
    orgname                varchar(250),
    positionunitcode       varchar(250),
    positionunitname       varchar(250),
    cellular               varchar(250),
    workcellular           varchar(250),
    managerpernr           varchar(250),
    firstnameheb           varchar(250),
    lastnameheb            varchar(250),
    positionname           varchar(250),
    jobname                varchar(250),
    unittypecode           varchar(250),
    unittypename           varchar(250),
    employeestatusid       integer,
    futureemployeestatusid integer,
    futureorgcode          varchar(250),
    futureareacode         varchar(250),
    futuresubareacode      varchar(250),
    futurestatusstartdate  timestamp,
    futureunittypecode     varchar(250),
    futureunittypename     varchar(250),
    futurepositionunitcode varchar(250),
    futurepositionunitname varchar(250),
    passportid             varchar(50),
    countrycode            varchar(50),
    countryname            varchar(100),
    sapakcode              integer,
    sapakname              varchar(100),
    ssapakcode             integer,
    sapaklocationcode      varchar(250),
    businessemail          varchar(100),
    countycalling          integer,
    taarif                 varchar(50),
    dwhcloudinsertdate     timestamp default timezone('Asia/Jerusalem'::text, now()) not null,
    companyregnumber       varchar(50)
);


