setwd("~/Git/all_la_verse")

nodes <- read.table(file.path("metadata", "index_text.txt"), header=T, row.names=1)
edges <- read.table(file.path("metadata", "index_run.txt"), 
                    colClasses=c("character", "integer", "integer"), 
                    header=T, row.names=1)

niko <- Vectorize(function(id, cutoff=8) {
  file_scores <- file.path("working", "scores", paste(id, "txt", sep="."))
  
  scores <- scan(file_scores, sep="\n", quiet=T)
  return(sum(scores>cutoff))
})


edges <- cbind(edges, 
   score=niko(row.names(edges)),
   tok=as.numeric(nodes[as.character(edges$source), "tokens"]) *
     as.numeric(nodes[as.character(edges$target), "tokens"]),
   label=paste(sep="~",
     nodes[as.character(edges$source), "label"],
     nodes[as.character(edges$target), "label"]
   )
)

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
