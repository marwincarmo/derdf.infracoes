
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
segurança dos transuentes. Identificar as infrações cometidas em cada
rodovia específica pode fornecer informações valiosas para a
implementação de fiscalização e políticas de prevenção de acidentes na
estrada.

### Objetivos da faxina

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
  dplyr::mutate(n_veic = sum(n)) %>% arrange(desc(n_veic)) %>% 
  # selecionando os principais veiculos registrados
  dplyr::filter(n_veic > 1000) %>% 
  dplyr::ungroup() %>% 
  dplyr::mutate(tipo_veiculo = forcats::fct_reorder(tipo_veiculo, n_veic, sum),
                grav_tipo = factor(grav_tipo, levels = c("Leve", "Média", "Grave", "Gravíssima"))) 
```

``` r
gravidade_veic %>% 
  ggplot() + 
  scale_colour_brewer(palette = "YlOrRd") +
  geom_col(aes(x = tipo_veiculo, y = n, fill = grav_tipo), position = "dodge") +
  coord_flip() +
  theme_minimal(12)
```

<img src="man/figures/README-unnamed-chunk-4-1.png" width="100%" />
