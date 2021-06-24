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
# e armazená-las na coluna adequada

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










usethis::use_data(DATASET, overwrite = TRUE)
