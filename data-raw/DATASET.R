# Pacotes -----------------------------------------------------------------

library(tidyverse)
library(janitor)
library(abjutils)

# 1) Leitura dos dados -------------------------------------------------------

base_bruta <- readr::read_csv2("data-raw/relatorio-de-infracoes-mes-04-2021.csv")
# ou
#base_bruta <- readr::read_csv2("http://dados.df.gov.br/dataset/3a3b7b40-c715-439d-9dff-f22b47fc5994/resource/e5ecdfc2-87aa-4747-8de5-b35701cf19c7/download/relatorio-de-infracoes-mes-04-2021.csv")

# Como as colunas são separadas por ";" a função readr::read_csv2()
# dá conta de abrir a nossa base de maneira correta e com o encoding adequado

# 2) Inspeção da base -----------------------------------------------------

tibble::glimpse(base_bruta)
tibble::view(base_bruta)

# A base é composta basicamente por colunas indicando o tipo da infração, a descrição
# da mesma, o tipo do infrator, tipo do veículo, a data e hora do cometimento,
# colunas detalhando o local e uma última classificando a infração quanto à gravidade
#
# Inspecionando visualmente, já é possível perceber algumas colunas que apresentam
# problemas para uma análise futura. Vamos inspecionar cada uma delas

base_bruta %>% dplyr::count(tipo_infracao) %>% tibble::view("tipo_infracao")
base_bruta %>% dplyr::count(descricao) %>% tibble::view("descricao")

# tipo_infracao se refere ao código da infracao, enquanto descricao descreve
# a infracao cometida. Ambas variáveis possuem 142 tipos diferentes, o que indica
# que cada código corresponde a uma descricao individual. Tudo ok com estas duas colunas

base_bruta %>% dplyr::count(tipo_infrator) %>% tibble::view("tipo_infrator")

# 3 tipos distintos de infratores, sendo condutor maioria absoluta
# também nada a consertar nesta coluna

base_bruta %>% count(tipo_veiculo) %>% view("tipo_veiculo")

# aqui temos uma grande diversidade de nomes que se referem ao mesmo tipo de veículo
# será necessária uma transformação para que estejam padronizados

# A coluna `cometimento` com a data da infração está no formato character.
# Será preciso transformá-la para data

# As colunas que se iniciam com `auinf_` informam o local exato onde a infração
# foi registrada. Um grande problema desta coluna é que para a maioria dos casos
# todas as informações estão concatenadas na coluna `auinf_local_rodovia`
# O trabalho da faxina nestas colunas será separar cada informação contida nestas strings
# e armazená-las na coluna adequada.
# Este documento (http://www.der.df.gov.br/wp-content/uploads/2018/01/Pardais_2011.pdf)
# dá a entender que o endereço registrado nessa coluna se refere ao endereço do equipamento
# de fiscalização eletrônica da velocidade dos veículos.

# por último, a coluna `grav_tipo` indica a gravidade da infração e está ok


# 2) Arrumacao das colunas ------------------------------------------------

#### 2.1) Coluna tipo_veiculos ----

# o primeiro passo será passar todos os nomes para a primeira letra em maisuclo
# e retirar os acentos

base_veiculo_arrumado <- base_bruta %>%
    dplyr::mutate(tipo_veiculo = abjutils::rm_accent(
        stringr::str_to_title(tipo_veiculo))
    )

base_veiculo_arrumado %>% count(tipo_veiculo) %>% print(n = Inf)

# passamos de 33 categorias distintas para 23. inspecionando a base o trabalho
# agora parece ser melhor resolvido agrupando as categorias repetidas em
# uma grafia única. Tambem há valores null que serão transformados em NA verdadeiros

lista_regex <- list(
    trator = c("C. Trator", "Caminhao Trator"),
    caminhonete = c("Caminhonet", "Caminhonete"),
    microonibus = c("Microonibu", "Microonibus"),
    motocicleta = c("Motociclet", "Motocicleta"),
    semi_reboque = c("S.reboque", "Semi-Reboque")
) %>%
    purrr::map(stringr::str_c, collapse = "|") %>%
    purrr::map(stringr::regex, ignore_case = TRUE)


base_veiculo_arrumado2 <- base_veiculo_arrumado %>%
    dplyr::mutate(tipo_veiculo = dplyr::case_when(
        stringr::str_detect(tipo_veiculo, lista_regex$trator) ~ "Caminhao Trator",
        stringr::str_detect(tipo_veiculo, lista_regex$caminhonete) ~ "Caminhonete",
        stringr::str_detect(tipo_veiculo, lista_regex$microonibus) ~ "Microonibus",
        stringr::str_detect(tipo_veiculo, lista_regex$motocicleta) ~ "Motocicleta",
        stringr::str_detect(tipo_veiculo, lista_regex$semi_reboque) ~ "Semi-Reboque",
        stringr::str_detect(tipo_veiculo, "Null") ~ NA_character_,
        TRUE ~ as.character(tipo_veiculo)
    )
    )

base_veiculo_arrumado2 %>% count(tipo_veiculo) %>% print(n = Inf)

# Reduzido para 19 categorias finais, incluindo uma NA, correspondente aos valores
# anteriormente codificados como "null"

#### 2.2) Data e hora da infração ----

# a coluna "cometimento" contém o dia em que a infração foi registrada, mas
# está codificada como character. para uma eventual análise, é interessante
# passá-la para o formato date
# a coluna hora_cometimento já está no formato time, não precisará
# ser tansformada

base_data_arrumada <- base_veiculo_arrumado2 %>%
    mutate(cometimento = lubridate::dmy(cometimento))

#### 2.3) Local da infração ----

# A princípio esta é a parte mais complicada da arrumação da base.
# O local da infração é categorizado pela rodovia, pelo km da rodovia, por um local
# de referencia e um complemento.
# Em algumas poucas colunas, está divisão está bem estabelecida, como:

base_data_arrumada %>%
    filter(!is.na(auinf_local_referencia)) %>%
    slice_sample(n = 10) %>%
    select(starts_with("auinf"))

# Em geral, todas estas informações estão agrupadas na coluna auinf_local_rodovia
# Inspecionando a base visualmente, alguns problemas já surgem: o código da rodovia
# está escrito com diferentes padrões, seja separando "DF" do código com espaço,
# sem espaço, com hífen, escrita em minúsculo etc. Além disto, na maior parte
# dos casos, junto com o código da estrada está a sigla da mesma
# Um primeiro passo será separar o código da sigla para padronizar, pois há
# casos onde há apenas o código sozinho.

# Mais um complicador, em alguns casos onde o nome da estrada não se inicia pelo
# codigo:

base_data_arrumada %>%
    dplyr::filter(!stringr::str_detect(auinf_local_rodovia, "^(D|d)")) %>%
    dplyr::select(starts_with("auinf")) %>%
    #dplyr::slice_sample(n = 10) %>%
    select(auinf_local_rodovia) %>% view()

# Há casos onde o local da infração é uma via de ligação entre duas estradas
# Em outros a estrada é uma BR
# Também casos nos quais constam apenas os números da sigla da estrada
# Alguns poucos casos representam erro de entrada de dados. No lugar da
# estrada foi colocado o sentido ou alguma outra informação


### 2.3.1) Referencia ----

# ponto de partida: adicionando tudo que vem depois de sentido para a coluna
# de referência. É possível ver que nesta coluna estão majoritariamente
# informações sobre o sentido da rodovia onde ocorreu a infração
#
base_data_arrumada %>%
    count(auinf_local_referencia) %>%
    view("referencia")

# esta função irá extrair tudo que começa com "sent" (ignorando capitalizaçao)
pegar_sentido <- function(x) {
    x %>%
        stringr::str_extract(regex("(SENT.*)", ignore_case = TRUE))
}
# como algumas observações já tem um valor nesta coluna, vamos substituir apenas
# aquelas que estão vazias

base_sentido_arrumado <- base_data_arrumada %>%
    dplyr::mutate(auinf_local_referencia = dplyr::case_when(
        is.na(auinf_local_referencia) ~ pegar_sentido(auinf_local_rodovia),
        TRUE ~ auinf_local_referencia
    ))

# verificando os casos que ainda estão vazios
base_sentido_arrumado %>%
    filter(is.na(auinf_local_referencia)) %>%
    view()

# inspecionando visualmente a base, vemos que as células vazias são
# na maior parte, os casos onde o local é uma via de ligação, sem informacao de sentido
# mas há também os casos de erro de entrada, onde o sentido foi colocado
# na coluna de complemento. isto pode ser facilmente resolvido com a função `dplyr::coalesce()`
# utilizando esta função copiamos o valor da coluna `auinf_local_complemento` para os casos
# de NA da coluna `auinf_local_referencia`

base_sentido_arrumado2 <- base_sentido_arrumado %>%
    dplyr::mutate(
        auinf_local_referencia = dplyr::coalesce(
            auinf_local_referencia, auinf_local_complemento)) %>%
    dplyr::mutate( # removendo os acentos para padronizar
        auinf_local_referencia = abjutils::rm_accent(toupper(auinf_local_referencia)))

base_sentido_arrumado3 %>%
    count(auinf_local_referencia) %>%
    view("referencia3")

# ainda há algumas discrepâncias. fazer uma transformação "padrão" na coluna toda
# (como retirar ponto final, eliminar espaços desnecessários) pode afetar linhas
# não problemáticas de forma indesejada. vamos optar por fazer uma transformação
# "na marra" nos casos problemáticos com maior frequência

base_sentido_arrumado3 <- base_sentido_arrumado2 %>%
  mutate(auinf_local_referencia = dplyr::case_when(
  stringr::str_detect(auinf_local_referencia,
                      regex("SENT. N. BAND / RIACHO FUNDO|SENT. N. BAND. / RIACHO FUNDO")) ~ "SENT. N. BAND / RIACHO FUNDO",
  stringr::str_detect(auinf_local_referencia,
                      regex("SENTIDO BALAO DO TORTO|SENTIDO BALAO DO TORTO.")) ~ "SENTIDO BALAO DO TORTO",
  stringr::str_detect(auinf_local_referencia,
                      regex("SENTIDO BARRAGEM DO PARANOA|SENTIDO BARRAGEM PARANOA")) ~ "SENTIDO BARRAGEM DO PARANOA",
  stringr::str_detect(auinf_local_referencia,
                      regex("SENTIDO BR-040|SENTIDO BR 040")) ~ "SENTIDO BR 040",
  stringr::str_detect(auinf_local_referencia,
                      regex("SENTIDO CRESCENTE|SENTIDO CRESCENTE.|SENTINDO CRESCENTE")) ~ "SENTIDO CRESCENTE",
  stringr::str_detect(auinf_local_referencia,
                      regex("SENTIDO DECRESCENTE|SENTIDO DECRESCENTE.")) ~ "SENTIDO DECRESCENTE",
  stringr::str_detect(auinf_local_referencia,
                      regex("SENTIDO NORTE  . (ALT. CANDANGOLANDIA) (VIA MARGINAL)")) ~ "SENTIDO NORTE - (ALT. CANDANGOLANDIA) (VIA MARGINAL)",
  stringr::str_detect(auinf_local_referencia,
                      regex("SENTIDO NORTE  . (ALT. CANDANGOLANDIA) (VIA PRINCIPAL)")) ~ "SENTIDO NORTE - (ALT. CANDANGOLANDIA) (VIA PRINCIPAL)",
  stringr::str_detect(auinf_local_referencia,
                      "SENTIDO BIDIRECIONAL ( PISTA SUL)") ~ "SENTIDO BIDIRECIONAL (PISTA SUL)",
  TRUE ~ auinf_local_referencia
   ))

#SENTIDO BIDIRECIONAL ( PISTA SUL)
"SENTIDO NORTE \u0096 (ALT. CANDANGOLANDIA) (VIA MARGINAL)"
base_sentido_arrumado2 %>%
    dplyr::mutate(auinf_local_referencia = dplyr::case_when(stringr::str_detect(auinf_local_referencia, regex("SENT. N. BAND. / RIACHO FUNDO")) ~ "SENT. N. BAND / RIACHO FUNDO"))


### 2.3.2) Km da pista ----

# o número da quilômetro da rodovia está com alguns padrões distintos
# pode ser um número inteiro de um ou dois dígitos, ou um número decimal
# com um ou dois dígitos antes e/ ou depois da vírgula
# vamos pegar apenas o número, sem o "km", como estão os valores já
# presentes na coluna auinf_local_km
# o km da pista é sempre a primeira ocorrência

pegar_km <- function(x) {
    num_km <- "(\\d+(,)\\d+|\\d+)" # formatos de como o número pode estar escrito
    x %>%
        stringr::str_extract(regex("KM.*[0-9]", ignore_case = TRUE)) %>%
        stringr::str_extract(num_km)
}

base_km_arrumado <- base_sentido_arrumado3 %>%
    dplyr::mutate(auinf_local_km = dplyr::case_when(
        is.na(auinf_local_km) ~ pegar_km(auinf_local_rodovia),
        TRUE ~ auinf_local_km
    ))

# conferindo quem ainda está com NA

base_km_arrumado %>%
    dplyr::filter(is.na(auinf_local_km)) %>%
    tibble::view()
# vazios apenas vias de ligação que não possuem dados de km e entradas
# já anteriormente vazias desta informação


### 2.3.3) Complemento ----

# verificando a coluna auinf_local_complemento, há muitos casos onde se repete
# o km da pista, outros onde se repete a sigla da rodovia e o sentido.
# mas também tem os casos onde o valor representa um complemento real à informação
# do local presente nas colunas anteriores
#
# em muitos casos, a informação do complemento está após a informação de sentido
# ou no meio do "local". Como esta informação se encontra em diversas formas
# e sem necessariamente um padrão, vamos deixar como está por enquanto


### 2.3.4) Nome da rodovia ----

# Na grande maioria das observações, esta informação é a primeira apresentada
# na coluna auinf_local_rodovia. Segundo a página da wikipedia das rodovias
# distritais do DF (https://pt.wikipedia.org/wiki/Lista_de_rodovias_distritais_do_Distrito_Federal_(Brasil)),
# "a nomenclatura das rodovias é definida pelo prefixo DF–xxx mais três algarismos."
# No entanto, como já foi visto, também há BRs e locais que são vias de ligação
# Começando pelo mais frequente, vamos buscar o padrão Sigla de duas letras, seguido de 2 ou mais algarismos
# (há casos com apenas 2) e da sigla da rodovia entre parêntesis (se houver)

pegar_rodovia <- function(x) {
    # limpando o anos
    rodovia_nome <- regex("(^[A-Z][A-Z].*[0-9]{2,}.*\\(.*\\)|^[A-Z][A-Z].*[0-9]{2,})", ignore_case = TRUE)
    x %>%

        stringr::str_extract(rodovia_nome)
}

# testando a função pegar_rodovia, os casos que são via de ligação também são coletados
# pois o padrão bate (começa com letras, vem qualquer coisa, e finaliza com parentesis).
# isto não é ruim, também é o nome do local específico (o que poderia ser um
# problema acabou virando uma solução)
# o único problema é que há grafias diferentes para a via, como VIA DE LIGACAO ou V. DE LIGACAO
# o primeiro passo então é padronizar isso

base_rodovia_arrumado_via <- base_km_arrumado %>%
    dplyr::mutate(auinf_local_rodovia = case_when(
        stringr::str_detect(auinf_local_rodovia, regex("v.", ignore_case = TRUE)) ~ str_replace(auinf_local_rodovia, regex("v\\.", ignore_case = TRUE), "VIA"),
        TRUE ~ auinf_local_rodovia
    ))

# agora vamos passar a informação da rodovia para uma nova coluna para termos ela isolada
# vamos manter o mesmo padrão de nomeação das colunas de local

base_rodovia_arrumada_local <- base_rodovia_arrumado_via %>%
    mutate(auinf_local_rodovia_codigo = pegar_rodovia(auinf_local_rodovia),
           .after = auinf_local_rodovia
    )

base_rodovia_arrumada_local %>%
    filter(is.na(auinf_local_rodovia_codigo)) %>%
    view()

# dois problemas aparecem logo de cara. primeiro que o regex para parar no
# parentesis da sigla é falho, pois há MUITOS nomes com parentesis depois da sigla
#
# ao observar os casos com NA na coluna nova, vemos que tem rodovias onde
# consta apenas o número, sem a sigla procedendo e vias de ligacao
# que não correspondem ao padrão da maioria. também há alguns
# onde só está a abreviação do nome da rodovia.
# vamos padronizar colocando o DF na frente dos números e consertando os que estão só com
# a abreviatura do nome

base_rodovia_arrumada_local_2 <- base_rodovia_arrumada_local %>%
    dplyr::mutate(auinf_local_rodovia_codigo = dplyr::case_when(
        stringr::str_detect(auinf_local_rodovia, "^\\d{3}") ~ paste0("DF-", auinf_local_rodovia),
        TRUE ~ auinf_local_rodovia_codigo
    ))


# funçãozinha para remover o que vem depois do codigo da rodovia. a maioria vem seguida
# do KM da pista, então vamos retirar tudo que vem depois de KM e dar uma arrumada
# retirando espaços desnecessários e trocando a separação de todas para "-"

remover_restante <- function(x) {
    stringr::str_remove(x, regex("KM.*", ignore_case = TRUE)) %>%
        toupper() %>%
        stringr::str_squish() %>%
        stringr::str_replace("-", " ") %>%
        stringr::str_wrap() %>%
        stringr::str_replace(" ", "-") %>%
        stringr::str_remove_all(",")
}

# o que sobra nas strings é o complemento. como agora temos uma informação menos misturada
# fica mais fácil de identificar o complemento do local e passá-lo para a coluna certa

pegar_complemento <- function(x) {
    stringr::str_extract(x,
                regex("(VIA|TRECHO|ESTRUTURAL|EIX.+).*",
                      ignore_case = TRUE)) %>%
        stringr::str_remove_all("\\)$")
}

# vamos buscar este padrão para o codigo
padrao_codigo <- regex("^[A-Z]{2}( |-)*[0-9]{2,}", ignore_case = TRUE)

# arrumar a coluna do codigo extraindo as letras e numeros e colando-os
# separando por hífen
arrumar_codigo <- function(x) {
    padrao_codigo <- regex("^[A-Z]{2}( |-)*[0-9]{2,}", ignore_case = TRUE)
    sigla <- stringr::str_extract(x, padrao_codigo)
    letra <- stringr::str_extract(sigla, "[A-Z]{2}")
    numero <- stringr::str_extract(sigla, "[0-9]{2,}")
    nova <- paste0(letra, "-", numero)
    nova
}

# agora vamos aplicar as funções na base para obtermos os codigos padronizados e
# colocar a informação do complemento na coluna adequada

base_rodovia_arrumada_local_3 <- base_rodovia_arrumada_local_2 %>%
    mutate(auinf_local_rodovia_codigo = case_when(
        # retiramos as informações repetidas do codigo
        str_detect(auinf_local_rodovia, padrao_codigo) ~ remover_restante(auinf_local_rodovia),
        TRUE ~ auinf_local_rodovia_codigo
    ), # passamos essas informações de complemento para a coluna certa
    auinf_local_complemento = case_when(
        str_detect(auinf_local_rodovia_codigo, padrao_codigo) ~ pegar_complemento(auinf_local_rodovia_codigo),
        TRUE ~ auinf_local_complemento),
    # damos uma ultima arrumadinha na sigla para deixar padronizada
    auinf_local_rodovia_codigo = case_when(
        str_detect(auinf_local_rodovia_codigo, padrao_codigo) ~ arrumar_codigo(auinf_local_rodovia_codigo),
        TRUE ~ auinf_local_rodovia_codigo)
    )

# um último toque final será criar uma coluna com o nome completo das rodovias para fins de identificação
# podemos obter estas informações raspando os dados da wikipedia:

wiki_url <- "https://pt.wikipedia.org/wiki/Lista_de_rodovias_distritais_do_Distrito_Federal_(Brasil)"
r_wiki <- httr::GET(wiki_url)

rodovias <- purrr::map(c(3:7), function(x) {
    r_wiki %>%
        xml2::read_html() %>%
        xml2::xml_find_all(paste0('/html/body/div/div/div[1]/div[2]/main/div[2]/div[3]/div[1]/ul[',x,']/li')) %>%
        rvest::html_text()
}) %>%
    unlist() %>%
    stringr::str_squish() %>%
    as_tibble_col(column_name = "nome") %>%
    separate(nome, into = c("sigla_rodovia", "nome_rodovia"), sep = " – ")

# somente as Rodovias de contorno e radiais estão/ são nomeadas, mas já é alguma coisa
base_rodovia_arrumada_local_com_nomes <- base_rodovia_arrumada_local_3 %>%
    dplyr::left_join(rodovias, by = c(auinf_local_rodovia_codigo = "sigla_rodovia"))


base_rodovia_arrumada_local_com_nomes %>%
    view("base_final")


# 3) Construção da base final tidy ----------------------------------------

base_infracoes_derdf_abril_21 <- base_rodovia_arrumada_local_com_nomes

usethis::use_data(base_infracoes_derdf_abril_21, overwrite = TRUE)
