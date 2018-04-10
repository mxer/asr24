#!/bin/bash

if [ $# != 1 ]; then
  echo "Usage: $0 <newlangdir>"
  echo "<newlangdir> must include lang/clean.txt."
  echo "<newlangdir>/local/dict/ must include lexicon.txt, extra_questions.txt, nonsilence_phones.txt, optional_silence.txt, silence_phones.txt, topo, words.txt"
  echo "SRILM must be in your path."
  exit 1
fi
newlangdir=$1

# Set up environment variables.
. cmd.sh
. path.sh

# Find SRILM.
if ! ngram-count &> /dev/null; then
  if -e /scratch/users/jhasegaw/srilm/path.sh; then
    pushd /scratch/users/jhasegaw/srilm
    . /scratch/users/jhasegaw/srilm/path.sh
    popd
  else
    echo "$0: failed to find SRILM tools."
    exit -1
  fi
fi

# Get the paths of our input files.
model=exp/tdnn_7b_chain_online
phones_src=exp/tdnn_7b_chain_online/phones.txt
dict_src=${newlangdir}/local/dict
lm_src=${newlangdir}/lang/lm.arpa
 
lang=${newlangdir}/lang
dict=${newlangdir}/dict
dict_tmp=${newlangdir}/dict_tmp
graph=${newlangdir}/graph

# Compile the word lexicon, L.fst.
echo "$0: prepare_lang"
if [ $dict_src/lexiconp.txt -ot $dict_src/lexicon.txt ]; then
  rm $dict_src/lexiconp.txt
fi
utils/prepare_lang.sh --phone-symbol-table $phones_src $dict_src "<unk>" $dict_tmp $dict
 
# Create the grammar/language model, G.fst.
echo "$0: ngram-count"
ngram-count -text $lang/clean.txt -order 3 -limit-vocab -vocab $dict_src/words.txt -kndiscount -interpolate -lm $lm_src
gzip < $lm_src > $lm_src.gz
echo "$0: format_lm"
utils/format_lm.sh $dict $lm_src.gz $dict_src/lexicon.txt $lang
 
# Assemble the HCLG graph.
echo "$0: mkgraph"
utils/mkgraph.sh --self-loop-scale 1.0 $lang $model $graph
 
# To use this newly created model, also build a decoding configuration.
# Put these into the directory ${newlangdir}/conf.
echo "$0: prepare_online_decoding"
steps/online/nnet3/prepare_online_decoding.sh --mfcc-config conf/mfcc_hires.conf $lang exp/nnet3/extractor exp/chain/tdnn_7b ${newlangdir}