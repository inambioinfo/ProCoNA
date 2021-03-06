

setGeneric("toPermTest",
           function(pnet,numPermutes) {
               standardGeneric("toPermTest")
           })

setMethod("toPermTest",
          signature(pnet="proconaNet",
                    numPermutes="numeric"),
          function
### Uses the procona network object,
### the data with peptides as columns, samples in rows.
### And the power that the net was built at
### the number of permutations to do...
### Modules are permuted and mean topological overlap
### is recorded, constructing the null.  The number
### of random permutations with mean TO greater than
### observed provides the p-value.
          (
              pnet, ##<< ProCoNA network object.
              numPermutes=100  ##<< The number of permutations to perform
              ) {
              colors = mergedColors(pnet)
              tom = TOM(pnet)
              u_colors = unique(colors)
              u_colors = u_colors[u_colors != "NA" & u_colors != "0"]
              sizes   = vector("numeric", length(u_colors))
              pvalues = vector("numeric", length(u_colors))
              meantom = vector("numeric", length(u_colors))
              meanran = vector("numeric", length(u_colors))
              
              for(i in 1:length(u_colors)) {  # for each unique color
                  
                  color = u_colors[i]           #   it's this color
                  idx <- colors == color 
                  tomSubset <- tom[idx,idx]
                  meanTO <- mean(utri(tomSubset)) # mean of upper triangle
                  size <- sum(idx)                # idx is boolean with length == peptides in module
                  x = 1:length(colors)            # indices to sample from
                  
                  message("Permuting module: ", color, "\n")
                  message("   dim of TOM: ", dim(tomSubset), "\n")
                  
                                        # create null distribution
                  dist = vector("numeric", numPermutes+1)
                  dist[numPermutes+1]  <- meanTO
                  for(j in 1:numPermutes) {
                      pdx   <- sample(x, size, replace <-F)
                      ptom   <- tom[pdx,pdx]
                      pmean   <- mean(utri(ptom))
                      dist[j]  <- pmean
                  }

                                        # how many times did the permuted mean TO measure
                                        # greater than the real module mean TO?
                  pvalues[i]  <- sum(meanTO <= dist)/numPermutes
                  sizes[i]    <- size
                  meantom[i]  <- meanTO
                  meanran[i]  <- mean(dist)
              }
              
              to_test <- cbind(u_colors, sizes, meantom, meanran, pvalues)
              colnames(to_test) = c("module", "moduleSize", "TOMmean", "PermMean", "p-value")
              permtest(pnet) = to_test
              return(pnet)
### returns the network obj with the perm test
          })





setGeneric("peptideConnectivityTest",
           function(pnet,pepInfo,pepCol,protCol,repsPerProt) {
               standardGeneric("peptideConnectivityTest")
           })

setMethod("peptideConnectivityTest",
          signature(pnet="proconaNet",
                    pepInfo="data.frame",
                    pepCol="character",
                    protCol="character",
                    repsPerProt="numeric"
                    ),
          
          function
### This function will compare the connectivity between
### peptides linked to a given protein, against a randomly
### drawn, similarly sized, selection of peptides.
### The hypothesis is that peptides from a given protein
### should be more connected than random.
          (pnet,    ##<< The peptide net object
           pepInfo, ##<< The peptide information table, mapping peptides to proteins
           pepCol,   ##<< The string identifying the column in the pepInfo table with peptide ID
           protCol,   ##<< String identifying column in pepInfo with Protein ID.
           repsPerProt  ##<< number of repetitions for the null
           ) {
              pepInfo = pepInfo[which(pepInfo[,pepCol] %in% peptides(pnet)),] 
              uProts  = unique(pepInfo[,protCol])  # The unique proteins in the network
              message(length(uProts), " number of proteins being investigated.\n")
              connPeps = vector("numeric", length(uProts))  # peptides associated with uProt
              randPeps = vector("numeric", repsPerProt * length(uProts))  # random peptide connections
              i = 1
              j = 1
              numPeps = 0
              for (p in uProts) {
                  pepIdx = which(pepInfo[,protCol] == p)
                  ids    = as.character(pepInfo[pepIdx,pepCol])
                  x      = which(peptides(pnet) %in% ids) 
                  if (length(x) > 1) {
                      numPeps = numPeps + length(x)
                      m = TOM(pnet)[x,x]
                      connPeps[i] = mean(m[upper.tri(m)])
                      for (k in 1:repsPerProt) {
                          l = sample(1:nrow(TOM(pnet)), size=length(x), replace=F)
                          randM = TOM(pnet)[l,l]
                          randPeps[j] = mean(randM[upper.tri(randM)])
                          j <- j+1
                      }
                  } else {
                      connPeps[i] = NA
                      randPeps[j] = NA
                      j = j+1
                  }
                  names(connPeps)[i] <- p
                  i = i+1
              }
              message(numPeps, " number of peptides associated with these proteins.\n")
              return(list(t.test(connPeps, randPeps), connPeps, randPeps))
### Returns a list of the connected peptides and the random samples.
          }
          )





setGeneric("peptideCorrelationTest",
           function(dat,pepinfo,pepCol,protCol){
               standardGeneric("peptideCorrelationTest")
           })

setMethod("peptideCorrelationTest",
          signature(dat="matrix",
                    pepinfo="data.frame",
                    pepCol="character",
                    protCol="character"
                    ),
          function
### Take the data, and a mapping of peptides to
### proteins, and compute the correlation between
### peptides linked to a given protein. Compare
### to random.
          (dat,     ##<< The data with samples as rows and peptides as columns
           pepinfo, ##<< The mapping of peptides to proteins as a data frame
           pepCol,  ##<< The column name of peptide info table containing peptide IDs
           protCol  ##<< The column name of pepinfo info table containing protein IDs
           ) {
              
              pepinfo <- pepinfo[which(pepinfo[,pepCol] %in% colnames(dat)),] 
              uprots <- unique(pepinfo[,protCol]) 
              protcors <- c()
              randcors <- c()
              
              for(p in uprots) {
                                        # The peps of interest for protein p
                  peps     <- pepinfo[which(pepinfo[,protCol] == p), pepCol]
                  pepidx   <- which(colnames(dat) %in% peps)
                                        #message("protein: ", p, " has ", length(peps), " peptides... ",
                                        #length(pepidx), "are in the data.\n")
                  
                  if (length(pepidx) > 1) {
                      pcors    <- cor(dat[, pepidx], use="pairwise.complete.obs")
                      protcors <- c(protcors, pcors[upper.tri(pcors)])
                      rcors    <- cor(dat[,sample(1:ncol(dat), size=length(pepidx))], use="pairwise.complete.obs")
                      randcors <- c(randcors, rcors[upper.tri(rcors)])
                  }
              }

              return(t.test(protcors, randcors, na.rm=T))
              
### return a list of protein correlations and random correlations
          })




setGeneric("goStatTest",
           function(pnet, module,pepinfo,pepColName,protColName,
                    universe,onto,annot,pvalue,cond) {
               standardGeneric("goStatTest")
           })

setMethod("goStatTest",
          signature(pnet="proconaNet",
                    module="numeric",
                    pepinfo="data.frame",
                    pepColName="character",
                    protColName="character",
                    universe="character",
                    onto="character",
                    annot="character",
                    pvalue="numeric",
                    cond="logical"
                    ),

          function
### Wrapper function to run the hyperGTest from package GOstats
          (pnet, ##<< the procona network
           module, ##<< module of interest
           pepinfo, ##<< the mass tag info
           pepColName, ##<< column in mass tag info for peptides
           protColName, ##<< column in mass tag info for proteins
           universe,  ##<< the universe to consider, list of proteins
           onto,   ##<< the ontology catagory (bp etc).. 
           annot, ##<< the annotation database to use
           pvalue, ##<< pvalue cutoff
           cond      ##<< conditional parameter, see GOstats.
           ) {
              
                                        #mass tag ids in this module
              modpeps <- peptides(pnet)[which(mergedColors(pnet) == module)]
              
                                        #uniprot ids represented by whats in this module
              modprots <- unique(pepinfo[which(pepinfo[,pepColName] %in% modpeps), protColName])
              
                                        # the refseq IDs
              modegs <- universe[which(universe[,1] %in% modprots),2]
              
              if(length(which(is.na(modegs))) > 0) {
                  modegs <- modegs[-which(is.na(modegs))]
              }
              
              message("Number of peptides tested: ", length(modegs), "\n")
              
              params <- new("GOHyperGParams", geneIds = modegs,
                            universeGeneIds=universe[,2], ontology=onto,
                            pvalueCutoff=pvalue, conditional=cond,
                            testDirection="over", annotation=annot)
              
              return(hyperGTest(p=params))
### returns the results of the hyper geometric test.
          })







setGeneric("keggStatTest",
           function(pnet,module,pepinfo,pepColName,protColName,
                    universe,onto,annot,pvalue,cond) {
               standardGeneric("keggStatTest")
           })

setMethod("keggStatTest",
          signature(pnet="proconaNet",
                    module="numeric",
                    pepinfo="data.frame",
                    pepColName="character",
                    protColName="character",
                    universe="character",
                    onto="character",
                    annot="character",
                    pvalue="numeric",
                    cond="logical"
                    ),
          function
### Wrapper function to run the hyperGTest from package GOstats
          (pnet,        ##<< the procona network
           module,      ##<< module of interest
           pepinfo,     ##<< the mass tag info
           pepColName,  ##<< column in mass tag info for peptides
           protColName, ##<< column in mass tag info for proteins
           universe,    ##<< the universe to consider, first column is MTDB protein ID, second column is KEGG ID.
           onto,        ##<< the ontology catagory (bp etc).. 
           annot,       ##<< the annotation database to use
           pvalue,      ##<< pvalue cutoff
           cond         ##<< conditional parameter, see GOstats.
           ) {
  
                                        #mass tag ids in this module
              modpeps <- peptides(pnet)[mergedColors(pnet) == module]
              
                                        #uniprot ids represented by whats in this module
              modprots <- unique(pepinfo[pepinfo[,pepColName] %in% modpeps, protColName])
              
                                        # the KEGG IDs
              modkeggs <- universe[which(universe[,1] %in% modprots),2]
              
              if(any(is.na(modkeggs)) > 0) {
                  modkeggs <- modkeggs[!(is.na(modkeggs))]
              }
              
              message("Number of pathways found: ", length(modkeggs), "\n")
              
              params <- new("KEGGHyperGParams", geneIds = modkeggs,
                            universeGeneIds=universe[,2],
                            pvalueCutoff=pvalue,
                            testDirection="over", annotation=annot)
              
              return(hyperGTest(p=params))
### returns the results of the hyper geometric test.
          })





setGeneric("ppiPermTest",
           function(pnet,pepdat,pepinfo,pepColName,
                    pi_colName, pi_edges, threshold, iterations) {
               standardGeneric("ppiPermTest")
           })

setMethod("ppiPermTest",
          signature(pnet="proconaNet",
                    pepdat="matrix",
                    pepinfo="data.frame",
                    pepColName="character",
                    pi_colName="character",
                    pi_edges="data.frame",
                    threshold="numeric",
                    iterations="numeric"
                    ),

          function
### Performs a permutation test for enrichment of PPI edges given a database.
          (
              pnet,    ##<< procona network object
              pepdat,    ##<< the data matrix with peptides as columns.
              pepinfo,   ##<< Maps peptides to proteins ... same format as in ppiTable
              pepColName,   ##<< The column in pepinfo with peptide IDs... as in pepdat
              pi_colName,       ##<< The column in pepinfo that maps peptides to unit found in pi_edges
              pi_edges,         ##<< Must be two columns A-B ... sort out in vivo or in vitro in advance
              threshold = 0.33,    ##<< Centrality threshold for peptides.
              iterations = 1000    ##<< Number of repititions 
              ) {

                                        # remove self and non-unique interactions
              pi_edges <- unique(pi_edges) 
              idx <- pi_edges[,1] == pi_edges[,2]
              pi_edges <- pi_edges[!idx,]
              background <- unique(c(as.character(pi_edges[,1]),as.character(pi_edges[,2])))
                                        # background needs to match the peptides...
              pep_background <- as.character(pepinfo[pepinfo[,pi_colName] %in% background, pepColName])
              
              ## gather info about the network
              modules <- mergedColors(pnet)  
              peps <- peptides(pnet)
              umodules <- unique(modules)
              pvals <- unique(modules)
              names(pvals) <- unique(modules)
              
                                        # calculate kme of network
              MEs <- mergedMEs(pnet)
              kme <- signedKME(pepdat,MEs)
              rownames(kme) <- colnames(pepdat)
              
              m.name=vector("numeric", length(pvals))
              m.orig.size=vector("numeric", length(pvals))
              m.rel.size=vector("numeric", length(pvals))
              m.kme.size=vector("numeric", length(pvals))
              m.prot.size=vector("numeric", length(pvals))
              m.edge.observed=vector("numeric", length(pvals))
              m.edges=vector("list", length(pvals))
              
              for(i in 1:length(pvals)) { # for each module
                  module <- umodules[i]
                  mpeps <- peps[which(modules==module)]  # module peps
                  kme_label <- paste("kME",module,sep="")
                  col_kme <- which(kme_label == colnames(kme)) # module relevant kme column 
                  
                                        # filter peps that are in desired module and greater than threshold
                  idx <- (kme[,col_kme] > threshold) & (modules == module)
                  fpeps <- rownames(kme)[idx]
                  
                  print(paste("module analysis: ", module))
                  print(paste("probes that pass Kme and are within module: ", 
                              length(fpeps),sep=""))
                  
                  edges_test = vector(mode="integer", length=iterations); 
                  edges_test[] = 0;
                  p_overlap = 0;
                  p_observed = 0;
                  p_pvalue = 0;
                  
                                        # get background and focus on relevant module probes within it
                  fpeps = intersect(fpeps,pep_background)
                  fprots <- unique(as.character(pepinfo[pepinfo[,pepColName] %in% fpeps, pi_colName]))
                  print(paste("of these, ", length(fpeps), 
                              " are relevant to our PI network...", sep=""))
                  
                                        # if there are no graph members then don't run analysis 
                  n = length(fprots) 
                  if(n > 0) {
                      idx_sig = vector(mode="logical", length=n)
                      
                                        # iteration test, first iter gets true edges
                      for(j in 1:(iterations+1)) {
                                        # shuffle node labels after first iteration
                          if (j > 1) { ids = sample(background, n, replace=FALSE) }
                          else { ids = fprots }
                          
                          idx_sig[] = F
                          
                                        # go through the module edges (shuffled or not) and look for overlap
                          i1 = pi_edges[,1] %in% ids
                          i2 = pi_edges[,2] %in% ids
                          idx_sig = i1 & i2
                          
                          if(j == 1) {
                              print(paste("found ", sum(i1), " in the first column"))
                              print(paste("found ", sum(i2), " in the second column"))
                              print(paste(sum(i1 & i2), " observed edges"))
                              m.edges[[i]] = pi_edges[idx_sig,]
                          }
                          
                                        #if(j %% 100 == 0) { print(paste("at ",i)) }
                                        # record test results  
                          if(j == 1) {
                              p_observed = sum(idx_sig)
                          }
                          else { 
                              edges_test[j-1] = sum(idx_sig)
                          }
                      }
                      
                                        #print(paste("total observed edges: ", p_observed));
                                        #print("tests: ");
                                        #print(edges_test);
                      
                      p_pvalue = sum(edges_test >= p_observed)/length(edges_test);
                      print(paste("pvalue: ", p_pvalue));
                      print("*****");
                      
                      pvals[i] <- p_pvalue
                      m.name[i] <- module
                      m.orig.size[i] <- length(mpeps)
                      m.kme.size[i] <- sum(kme[,col_kme] > threshold & modules == module)
                      m.rel.size[i] <- length(fpeps)
                      m.prot.size[i] <- length(fprots)
                      m.edge.observed[i] <- p_observed
                  }
                  
                  if(n == 0) {
                      print("ERROR: no probes meet Kme threshold within module")
                  }
                  
              }
              
              pvals = as.numeric(pvals)
              names(pvals) = unique(modules)
              names(m.name) = unique(modules)
              names(m.orig.size) = unique(modules)
              names(m.kme.size) = unique(modules)
              names(m.prot.size) = unique(modules)
              names(m.edge.observed) = unique(modules)
              
              list(name=m.name,orig.size=m.orig.size,kme.size=m.kme.size,
                   num_proteins=m.prot.size,edge.observed=m.edge.observed,
                   pval=pvals, edges=m.edges)
### returns list of test results.
          })

