\name{MMvsPS}
\alias{MMvsPS}
\alias{MMvsPS,proconaNet,matrix,numeric,numeric-method}

\title{Module members vs Peptide Significance}
\description{Plots the module membership (correlation to eigenvector) against the peptide significance (correlation to phenotype) for a given trait and module}

\usage{MMvsPS(pnet, pepdat, phenoVec, mod)}

\arguments{
  \item{pnet}{The procona network}
  \item{pepdat}{the peptide data, with rows as samples and columns as peptides}
  \item{phenoVec}{the phenotypic trait, vector}
  \item{mod}{the module of interest}
}

\value{returns a list of module memberships and peptide significances.}


\examples{
data(ProCoNA_Data)
#net1 <- buildProconaNetwork("peptide network", peptideData, pow=13)
MMvsPS(net1, peptideData, phenotypes[,5], 1)
}
\author{David L Gibbs}





