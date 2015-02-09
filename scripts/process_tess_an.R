nodes <- read.table(file.path("metadata", "index_text.txt"), header=T, row.names=1)
edges <- read.table(file.path("metadata", "index_run.txt"), 
                    colClasses=c("character", "integer", "integer"), 
                    header=T, row.names=1)

nikolaev <- Vectorize(function(id, cutoff=8) {
  file_scores <- file.path("scores", paste(id, "txt", sep="."))
  
  scores <- scan(file_scores, sep="\n", quiet=T)
  return(sum(scores>cutoff))
})


edges <- cbind(edges, 
   score=nikolaev(row.names(edges)),
   tok=as.numeric(nodes[as.character(edges$source), "tokens"]) *
     as.numeric(nodes[as.character(edges$target), "tokens"]),
   label=paste(sep="~",
     nodes[as.character(edges$source), "label"],
     nodes[as.character(edges$target), "label"]
   )
)
edges <- cbind(edges,
  nscore = round(10^8 * edges$score/edges$tok, digits=2)
)
edges <- edges[order(edges$nscore, decreasing=T),]

feat <- data.frame(
  tok_s=as.numeric(nodes[as.character(edges$source), "tokens"]),
  tok_t=as.numeric(nodes[as.character(edges$target), "tokens"]),
  stm_s=as.numeric(nodes[as.character(edges$source), "stems"]),
  stm_t=as.numeric(nodes[as.character(edges$target), "stems"]),
  lin_s=nodes[as.character(edges$source), "lines"],
  lin_t=nodes[as.character(edges$target), "lines"],
  phr_s=nodes[as.character(edges$source), "phrases"],
  phr_t=nodes[as.character(edges$target), "phrases"],
  ttw_s=nodes[as.character(edges$source), "ttr_w"],
  ttw_t=nodes[as.character(edges$target), "ttr_w"],
  tts_s=nodes[as.character(edges$source), "ttr_s"],
  tts_t=nodes[as.character(edges$target), "ttr_s"],
  row.names=row.names(edges)
)

write.table(file="nodes.csv",
  x=data.frame(
    id=as.integer(row.names(nodes)),
    nodes[,c("label", "auth", "date", "tokens", "phrases", "lines")]),
  sep=",",
  row.names=F
)

write.table(file="edges.csv",
  x=data.frame(
    id=as.integer(row.names(edges)),
    source=edges$source,
    target=edges$target,
    label=edges$label,
    weight=edges$nscore
  ),
  sep=",",
  row.names=F
)
