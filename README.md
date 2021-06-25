
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
untidyness.

A começar pelos tipos de veículos infratores, há diversos registros se
referindo a um mesmo tipo de veículo com grafias diferentes, diferenças
no padrão de abreviação das palavras e de acentuação das letras, além
palavras com letras faltantes.

O maior problema desta base reside nas colunas de identificação do local
da infração. Elas se dividem em `auinf_local_rodovia`, `auinf_local_km`,
`auinf_local_referencia` e `auinf_local_complemento`. Apesar da
existência das colunas para a divisão dos detalhes do local, são poucos
registros que a obedecem. Na maior parte, se observa que todas as
informações relevantes para identificação do local da infraçã estão
concatenadas em uma única string na coluna `auinf_local_rodovia`. O
trabalho principal da faxina será extrair estas informações, colocá-las
em sua devida coluna e padronizar a grafia das siglas, complementos e
referências, já que também estão registradas das mais variadas formas.

A base de dados também fornece colunas de latitude e longitude. No
entanto, além de raros os registros os que estão disponíveis não parecem
fornecer uma localização válida.

### Fluxo da faxina: objetivos do script

### Visualização

``` r
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
  # selecionando os principais veiculos registrados
  dplyr::filter(n_veic > 1000) %>% 
  dplyr::ungroup() %>% 
  dplyr::mutate(tipo_veiculo = forcats::fct_reorder(tipo_veiculo, n_veic, sum),
                grav_tipo = factor(grav_tipo, levels = c("Leve", "Média", "Grave", "Gravíssima"))) 
```

``` r
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

<img src="man/figures/README-unnamed-chunk-4-1.png" width="100%" />

``` r
gravidade_rodovia <- base %>% 
  dplyr::group_by(auinf_local_rodovia_codigo, grav_tipo) %>% 
  dplyr::tally() %>% 
  # retirando NA e Vias de Ligação e selecionando as 
  # rodovias com mais de 1000 registros de infração
  dplyr::filter(!is.na(auinf_local_rodovia_codigo),
         !stringr::str_detect(auinf_local_rodovia_codigo, "VIA.")) %>% 
  dplyr::group_by(auinf_local_rodovia_codigo) %>% 
  dplyr::mutate(n_rodovia = sum(n)) %>%  
  # selecionando os principais veiculos registrados
  dplyr::ungroup() %>% 
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

<img src="man/figures/README-unnamed-chunk-5-1.png" width="100%" />

``` r
base %>% 
  dplyr::mutate(grav_tipo = factor(grav_tipo, levels = c("Leve", "Média", "Grave", "Gravíssima"))) %>% 
  ggplot(aes(x = hora_cometimento, y = ..density..)) +
  geom_freqpoly(mapping = aes(colour = grav_tipo), bins = 50) +
  scale_x_time(breaks = hms::hms(hours = seq(0, 24, 4))) +
  scale_color_viridis_d(option = "A", begin = .9, end = .1) +
  theme_minimal(12) +
  labs(x = "", colour = "Infração") +
  theme(axis.title.y=element_blank(),
        axis.text.y=element_blank(), 
        axis.ticks.y=element_blank(),
        axis.line.y = element_blank(),
        legend.position = c(.9,.5))
```

<img src="man/figures/README-unnamed-chunk-6-1.png" width="100%" />
