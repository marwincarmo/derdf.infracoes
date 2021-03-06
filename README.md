
<!-- README.md is generated from README.Rmd. Please edit that file -->

# derdf.infracoes

<!-- badges: start -->

[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
<!-- badges: end -->

Este pacote contém os dados de Autos de Infração registrados pelo
Departamento de Estradas de Rodagem do Distrito Federal no mes de Abril
de 2021.

## Instalação

``` r
# install.packages("devtools")
devtools::install_github("marwincarmo/derdf.infracoes")
```

## Introdução

Este relatório foi desenvolvido como trabalho final para o curso de
[Faxina de dados da Curso-R](https://curso-r.com/cursos/faxina/). O
objetivo do trabalho final é aplicar os conceitos ensinados no curso em
alguma base de dados de acesso público, transformando uma base untidy em
tidy. Em linhas gerais, uma base tidy deve apresentar cada observação em
uma só linha da tabela e cada variável de interesse ter sua própria
coluna.

### Apresentação da base

A base que será apresentada neste relatório foi obtida no [Portal
Brasileiro de Dados Abertos](https://dados.gov.br/). Esta plataforma
reune conjuntos de dados e informações públicas de diversas esferas da
administração pública.

A base escolhida foi o [Relatório de Infrações de
Trânsito](https://dados.gov.br/dataset/infracoes-transito) do
[Departamento de Estradas de Rodagem do Distrito
Federal](http://www.der.df.gov.br/) (DER-DF), do mês de Abril de 2021.
Estes dados foram escolhidos em uma busca casual por bases de dados
“bagunçadas” e que poderiam fornecer informações importantes após o
tratamento apropriado.

A página do DER-DF carece de relatórios detalhados sobre o registro de
infrações nas rodovias do estado. A análise cuidadosa destas informações
pode auxiliar na identificação da frequência e gravidade de infrações de
trânsito em cada rodovia do Distrito Federal. As Leis de Trânsito
fornecem normas e condutas para uma boa convivência no trânsito e
segurança dos transuentes. Identificar a frequência e gravidade das
infrações por infrator, local ou horário pode fornecer informações
valiosas para a implementação de fiscalização e políticas de prevenção
de acidentes na estrada.

### Objetivos da faxina

Embora a base apresente uma estrutura em que cada observação se encontra
em uma única linha, é nas colunas que residem os problemas de
*untidyness*.

A começar pelos tipos de veículos infratores, há diversos registros se
referindo a um mesmo tipo de veículo com grafias diferentes, diferenças
no padrão de abreviação das palavras e de acentuação das letras, além
palavras com letras faltantes.

O maior problema desta base reside nas colunas de identificação do local
da infração. Elas se dividem em `auinf_local_rodovia`, `auinf_local_km`,
`auinf_local_referencia` e `auinf_local_complemento`. Apesar da
existência das colunas para a divisão dos detalhes do local, são poucos
registros que a obedecem. Na maior parte, se observa que todas as
informações relevantes para identificação do local da infração estão
concatenadas em uma única string na coluna `auinf_local_rodovia`. O
trabalho principal da faxina será extrair estas informações, colocá-las
em sua devida coluna e padronizar a grafia das siglas, complementos e
referências, já que também estão registradas das mais variadas formas.

A base de dados também fornece colunas de latitude e longitude. No
entanto, além de raros os registros, os que estão disponíveis não
parecem fornecer uma localização válida.

### Fluxo da faxina: objetivos do script

O
[script](https://github.com/marwincarmo/derdf.infracoes/blob/master/data-raw/DATASET.R)
com os códigos de transformação da base segue o seguinte fluxo:

1.  Arrumação da coluna `tipo_veiculos` para padronizar o registro tipos
    de veículos infratores

2.  Passa os valores da coluna `cometimento` com o dia de registro da
    infração do formato character para o formato date.

3.  Extração dos dados de referência concatenados na coluna
    `auinf_local_rodovia` para a coluna agrupadora de cada informação
    específica. Primeiro se buscou a informação de sentido da rodovia,
    seguido da quilometragem do local da infração, o nome da rodovia e
    as informações complementares. Cada etapa seguiu uma sequência de
    extração, manipulação e padronização das informações.

### Análises

O detalhamento do local das infrações possibilitado pela faxina na base
original permite que se analise com detalhes informações sobre
categorias de veículos e tipos de infratores, bem como possibilita a
identificação de pontos específicos das rodovias onde se observam as
infrações e a gravidade das mesmas. O formato original da base de dados
impossibilitava que o usuário tivesse acesso a este tipo de informação
detalhada.

Com a base “limpa” algumas investigações se tornam possíveis:

#### Infrações por tipo de veículo

``` r
# carregando a base de dados e os pacotes para manipulação e visualização dos dados
library(tidyverse)
library(derdf.infracoes)
base <- derdf.infracoes::base_infracoes_derdf_abril_21
```

``` r
gravidade_veic <- base %>% 
  dplyr::group_by(tipo_veiculo, grav_tipo) %>% 
  dplyr::tally() %>% 
  dplyr::group_by(tipo_veiculo) %>% 
  dplyr::mutate(n_veic = sum(n)) %>%  
  # selecionando os veiculos com maiores números de registro
  dplyr::filter(n_veic > 1000) %>% 
  dplyr::ungroup() %>% 
  dplyr::mutate(tipo_veiculo = forcats::fct_reorder(tipo_veiculo, n_veic, sum),
                grav_tipo = factor(grav_tipo, levels = c("Leve", "Média", "Grave", "Gravíssima")))

gravidade_veic %>% 
  ggplot(aes(x = tipo_veiculo, y = n, fill = grav_tipo)) + 
  scale_fill_viridis_d(option = "A", begin = .9, end = .4) +
  geom_col(position = "dodge") +
  coord_flip() +
  labs(x = "Veículo", y = "Quantidade", fill = "Infração") +
  guides(fill = guide_legend(reverse = TRUE)) +
  theme_minimal(12) +
  theme(legend.position = c(.9,.5))
```

<img src="man/figures/README-unnamed-chunk-3-1.png" width="100%" />

É possível verificar que os automóveis são o tipo de veículo com o maior
registro de infrações, seguindo uma lógica, visto ser este o tipo de
veículo em maior número nas estradas. Também vemos que as infrações de
gravidade Média são mais frequentes para todos os principais tipos de
veículos analisados e que, em geral, infrações Graves e Gravíssimas tem
frequência semelhante.

#### Infrações por rodovia

``` r
gravidade_rodovia <- base %>% 
  dplyr::group_by(auinf_local_rodovia_codigo, grav_tipo) %>% 
  dplyr::tally() %>% 
  # retirando NA e Vias de Ligação
  dplyr::filter(!is.na(auinf_local_rodovia_codigo),
         !stringr::str_detect(auinf_local_rodovia_codigo, "VIA.")) %>% 
  dplyr::group_by(auinf_local_rodovia_codigo) %>% 
  dplyr::mutate(n_rodovia = sum(n)) %>%  
  dplyr::ungroup() %>% 
  # selecionando as principais rodovias registradas
  dplyr::filter(n_rodovia > 1000) %>% 
  dplyr::mutate(auinf_local_rodovia_codigo = forcats::fct_reorder(auinf_local_rodovia_codigo, n_rodovia),
                grav_tipo = factor(grav_tipo, levels = c("Leve", "Média", "Grave", "Gravíssima"))) 
  
gravidade_rodovia %>% 
  ggplot(aes(x = auinf_local_rodovia_codigo, y = n, fill = grav_tipo)) + 
  scale_fill_viridis_d(option = "A", begin = .9, end = .4) +
  geom_col() +
  coord_flip() +
  labs(x = "Rodovia", y = "Quantidade", fill = "Infração") +
  guides(fill = guide_legend(reverse = TRUE)) +
  theme_minimal(12) +
  theme(legend.position = c(.9,.5))
```

<img src="man/figures/README-unnamed-chunk-4-1.png" width="100%" />

O volume de infrações cometidas na DF-075 é substancialmente maior do
que nas demais rodovias. Outro destaque é que a DF-001 é a rodovia com
maiores índices de infrações Graves e Gravíssimas dentre todas as
analisadas.

#### Infrações por horário

``` r
base %>% 
  dplyr::mutate(grav_tipo = factor(grav_tipo, levels = c("Leve", "Média", "Grave", "Gravíssima"))) %>% 
  ggplot(aes(x = hora_cometimento, y = ..density..)) +
  geom_freqpoly(mapping = aes(colour = grav_tipo), bins = 50) +
  scale_x_time(breaks = hms::hms(hours = seq(0, 24, 4))) +
  scale_color_viridis_d(option = "A", begin = .9, end = .1) +
  guides(colour = guide_legend(reverse = TRUE)) +
  theme_minimal(12) +
  labs(x = "", colour = "Infração") +
  theme(axis.title.y=element_blank(),
        axis.text.y=element_blank(), 
        axis.ticks.y=element_blank(),
        axis.line.y = element_blank(),
        legend.position = c(.9,.5))
```

<img src="man/figures/README-unnamed-chunk-5-1.png" width="100%" />

É possível ver que infrações Graves e Gravíssimas tem um pico maior no
horário da manhã e ao final da tarde, enquanto que as Leves e Médias
apresentam uma certa constância durante o dia.
