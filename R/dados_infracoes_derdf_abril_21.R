#' Autos de Infracao DER-DF - Abril/ 2021.
#'
#' Um conjunto de dados contendo ifnormacoes a respeito das infracoes registradas
#'  pelo Departamento de Estradas de Rodagem do Distrito Federal no mes de Abril de 2021.
#'
#' @format Um objeto de classe `tbl_df` (inherits from tbl, data.frame) com 82223 linhas e 15 colunas.
#'  \describe{
#'   \item{tipo_infracao}{Codigo da infracao}
#'   \item{descricao}{Descricao da infracao}
#'   \item{tipo_infrator}{Tipo do infrator}
#'   \item{tipo_veiculo}{Tipo do veiculo infrator}
#'   \item{cometimento}{Dia registrado da infracao}
#'   \item{hora_cometimento}{Horario do registro da infracao}
#'   \item{auinf_local_rodovia}{Informacao completa do local de infracao}
#'   \item{auinf_local_rodovia_codigo}{Codigo da rodovia onde foi feito o registro}
#'   \item{auinf_local_km}{Altura da rodovia onde foi feito o registro}
#'   \item{auinf_local_referencia}{Sentido da rodovia onde foi feito o registro}
#'   \item{auinf_local_complemento}{Informacao complementar sobre o local}
#'   \item{auinf_local_latitude}{Latitude do local de registro}
#'   \item{auinf_local_longitude}{Longitude do local de registro}
#'   \item{grav_tipo}{Nivel de gravidade da infracao}
#'   \item{nome_rodovia}{Nome da rodovia}
#'
#'   }
#' @source \url{https://dados.gov.br/dataset/infracoes-transito/resource/e5ecdfc2-87aa-4747-8de5-b35701cf19c7}
"base_infracoes_derdf_abril_21"
