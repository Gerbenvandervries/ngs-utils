#!/bin/bash
set -u
set -e
underline=`tput smul`
normal=`tput sgr0`
bold=`tput bold`

function usage () {
echo "
${bold}This script is calculating coverage calculations per target and per Gene based on coverage_per_target files created by DepthOfCoverage.
AvgCoverage, median, percentage <10x,<20x,<50x,<100x coverage


${bold}Arguments${normal}

	example sh countCoverage.sh -p Exoom_v1 OPTIONS

	Required:
	-p|--panel		Name of the panel/capturingkit, e.g. Exoom_v1, CARDIO_v3
	Optional:
	-w|--workdir		working directory (default: /groups/umcg-gaf/tmp04/coverage/{panel})
	-s|--structure		relative path from permanentDir that contains coveragepertarget files(default: run01/results/coverage/CoveragePerTarget/)
	-d|--permanentdir	location of the permanantDir (default: /groups/umcg-gd/prm02/projects/)
	-t|--tmp		Give tmpfolder location (default: \${workdir}/tmp)

It will automatically get all files that are in the structure, the following command will be executed:
e.g.
command: ls \${permanentDir}/*\${panel}/\${structure}/*\${panel}*.coveragePerTarget.txt
weaved command: ls /groups/umcg-gd/prm02/projects/*-Exoom_v1/run01/results/coverage/CoveragePerTarget/*Exoom_v1*.coveragePerTarget.txt"


}

module load ngs-utils
PARSED_OPTIONS=$(getopt -n "$0"  -o p:w:s:d:t: --long "name:panel:workdir:structure:permanentdir:tmp:"  -- "$@")

#
# Bad arguments, something has gone wrong with the getopt command.
#
if [ $? -ne 0 ]; then
        usage
        echo "FATAL: Wrong arguments."
        exit 1
fi

eval set -- "$PARSED_OPTIONS"

#
# Now goes through all the options with a case and using shift to analyse 1 argument at a time.
# $1 identifies the first argument, and when we use shift we discard the first argument, so $2 becomes $1 and goes again through the case.
#
while true; do
  case "$1" in
        -p|--panel)
                case "$2" in
                "") shift 2 ;;
                *) PANEL=$2 ; shift 2 ;;
            esac ;;
	-w|--workdir)
                case "$2" in
                *) WORDKIR=$2 ; shift 2 ;;
            esac ;;
	-s|--structure)
                case "$2" in
                *) STRUCTURE=$2 ; shift 2 ;;
            esac ;;
	-d|--permanentdir)
                case "$2" in
                *) PRMDIR=$2 ; shift 2 ;;
            esac ;;
	-t|--tmp)
                case "$2" in
                *) TMP=$2 ; shift 2 ;;
            esac ;;
        --) shift ; break ;;
        *) echo "Internal error!" ; exit 1 ;;
  esac
done

empty=""
#
# Check required options were provided.
if [[ -z "${PANEL-}" ]]; then
	usage
	exit 1
fi
if [[ -z "${WORKDIR-}" ]]; then
	WORKDIR="/groups/umcg-gaf/tmp04/coverage/${PANEL}/"
fi
if [[ -z "${STRUCTURE-}" ]]; then
        STRUCTURE="run01/results/coverage/CoveragePerTarget/"
fi
if [[ -z "${PRMDIR-}" ]]; then
        PRMDIR="/groups/umcg-gd/prm02/projects/"
fi
if [[ -z "${TMP-}" ]]; then
	TMP=${WORKDIR}/tmp/
	mkdir -p ${TMP}	
	echo "makedir ${TMP}"
fi
echo "starting"

rm -rf ${WORKDIR}
mkdir -p ${WORKDIR}/coverage/
mkdir -p ${WORKDIR}/tmp/

echo "starting to extract all the ${PANEL} projects and retreive the coverage for each sample"
echo "ls ${PRMDIR}/*${PANEL}/${STRUCTURE}/*${PANEL}*.coveragePerTarget.txt"
count=0
SAMPLES=()
REJECTEDSAMPLES=()
if ls ${PRMDIR}/*${PANEL}/${STRUCTURE}/*${PANEL}*.coveragePerTarget.txt 1> /dev/null 2>&1
then
	for i in $(ls ${PRMDIR}/*${PANEL}/${STRUCTURE}/*${PANEL}*.coveragePerTarget.txt)
	do
		sampleName="$(basename "${i%%.*}")"
		SAMPLES+=("${sampleName}")
		if [ $count == 0 ]
		then
			awk '{print $2,$3,$4,$6}' $i > ${TMP}/firstcolumns.txt
			count=$((count+1))
		fi

		NAMEFILE=$(basename $i)
		DIRNAME=$(dirname $i)
		SAMPLENAME=${NAMEFILE%%.*}
		#awk '{sum+=$5}END {print sum/210414}' $i > $DIRNAME/$SAMPLENAME.averageCoverage.txt
		awk '{print $5}' $i > ${WORKDIR}/coverage/${SAMPLENAME}.coverage
		totalcount=$(($(cat ${WORKDIR}/coverage/${SAMPLENAME}.coverage | wc -l)-1))
		count=0
		count=$(awk 'BEGIN{sum=0}{if($1 < 20){sum++}} END {print sum}' ${WORKDIR}/coverage/${SAMPLENAME}.coverage)

		if [ $count == 0 ]
		then
			percentage=0
			#echo "${SAMPLENAME}:percentage = $percentage"
		else
			percentage=$(echo $((count*100/totalcount)))
			if [ ${percentage%%.*} -gt 10 ]
			then
				echo "${SAMPLENAME}: percentage $percentage ($count/$totalcount) is more than 10 procent, skipped"
				REJECTEDSAMPLES+=("${SAMPLENAME}")

				continue
			fi
		fi
	done
else
	echo "No samples found for this capturingkit, EXIT"
        exit 1
fi

for i in "${REJECTEDSAMPLES[@]}"
do
	echo "removed ${WORKDIR}/coverage/${i}.coverage"
	rm ${WORKDIR}/coverage/${i}.coverage
done

echo ${SAMPLES[@]} > ${TMP}/headers.txt

echo "${WORKDIR}/coverage/"

total=$(ls ${WORKDIR}/coverage/*.coverage | wc -l)

paste ${WORKDIR}/coverage/*.coverage > ${TMP}/coverageAllSamples.txt


echo "## calculate MEDIAN ##"
## calculate MEDIAN ##
awk -v max=1 '
        function median(c,v,  j) { 
           asort(v,j); 
           if (c % 2) return j[(c+1)/2]; 
           else return (j[c/2+1]+j[c/2])/2.0; 
        } 
{ 
         count++;values[count]=$NF;  
         if (count >= max) { 
           print  median(count,values); count=0; 
         } 
} 
END { 
         print  median(count,values); 
}' ${TMP}/coverageAllSamples.txt > ${TMP}/coverageAllSamples_Median.txt
echo "## calculate SD ##" 
## calculate SD
awk '{ A=0; V=0; for(N=1; N<=NF; N++) A+=$N ; A/=NF ; for(N=1; N<=NF; N++) V+=(($N-A)*($N-A))/(NF-1); print sqrt(V) }' ${TMP}/coverageAllSamples.txt > ${TMP}/coverageAllSamples_SD.txt

echo "## calculate AVG ##"
## CALCULATE AVG
awk '{ for(i = 1; i <= NF; i++) sum+=$i;print sum/NF;sum=0 }' ${TMP}/coverageAllSamples.txt > ${TMP}/coverageAllSamples_AVG.txt

echo "## Calculate percentage under 10,20,50 and 100x ##"
## Calculate percentage under 10,20,50 and 100x ##
awk '{ for(i = 1; i <= NF; i++) if ($i < 10 )counter+=1;print 100-((counter/NF))*100;counter=0 }'  ${TMP}/coverageAllSamples.txt > ${TMP}/coverageAllSamples_moreThan10x.txt
awk '{ for(i = 1; i <= NF; i++) if ($i < 20 )counter+=1;print 100-((counter/NF))*100;counter=0 }'  ${TMP}/coverageAllSamples.txt > ${TMP}/coverageAllSamples_moreThan20x.txt
awk '{ for(i = 1; i <= NF; i++) if ($i < 50 )counter+=1;print 100-((counter/NF))*100;counter=0 }'  ${TMP}/coverageAllSamples.txt > ${TMP}/coverageAllSamples_moreThan50x.txt
awk '{ for(i = 1; i <= NF; i++) if ($i < 100 )counter+=1;print 100-((counter/NF))*100;counter=0 }'  ${TMP}/coverageAllSamples.txt > ${TMP}/coverageAllSamples_moreThan100x.txt

awk 'BEGIN{OFS="\t"}{print $1,$2,$3,$4}' ${TMP}/firstcolumns.txt > ${TMP}/first4columns.txt

echo "## update column gene with only	one annotation possible"
## update column gene with only one annotation possible
awk '{print $4}' ${TMP}/first4columns.txt | awk '{FS=",|:"}{print $1}' > ${TMP}/UpdatedGenes.txt
awk 'BEGIN{OFS="\t"}{print $1,$2,$3}' ${TMP}/first4columns.txt > ${TMP}/chromstartstop.txt
paste ${TMP}/chromstartstop.txt  ${TMP}/UpdatedGenes.txt > ${TMP}/BigupdatedFile.txt

echo "pasting median,avg,10x,20x,50x and 100x"
rm -f ${WORKDIR}/CoverageOverview.txt

paste -d '\t' ${TMP}/BigupdatedFile.txt ${TMP}/coverageAllSamples_Median.txt ${TMP}/coverageAllSamples_AVG.txt ${TMP}/coverageAllSamples_SD.txt ${TMP}/coverageAllSamples_moreThan10x.txt ${TMP}/coverageAllSamples_moreThan20x.txt ${TMP}/coverageAllSamples_moreThan50x.txt ${TMP}/coverageAllSamples_moreThan100x.txt > ${TMP}/pasteAllInfoTogether.txt
echo -e "Chr\tStart\tStop\tGene\tMedian\tAvgCoverage\tSD\tu10\tu20\tu50\tu100" > ${WORKDIR}/CoverageOverview.txt
tail -n+2 ${TMP}/pasteAllInfoTogether.txt >> ${WORKDIR}/CoverageOverview.txt 
head -n -1 ${WORKDIR}/CoverageOverview.txt > ${TMP}/CoverageOverview.txt.tmp
cp ${TMP}/CoverageOverview.txt.tmp ${WORKDIR}/CoverageOverview_basedOn_${total}_Samples.txt

echo "DONE, final file is ${WORKDIR}/CoverageOverview_basedOn_${total}_Samples.txt"
echo "now creating per Gene calculations"
ml ngs-utils
#python ${EBROOTNGSMINUTILS}/countCoveragePerGene.py ${WORKDIR}/CoverageOverview.txt > ${WORKDIR}/CoverageOverview_PerGene.txt
echo "python ~/github/ngs-utils/countCoveragePerGene.py ${WORKDIR}/CoverageOverview_basedOn_${total}_Samples.txt  > ${WORKDIR}/CoverageOverview_PerGene.txt"
python ~/github/ngs-utils/countCoveragePerGene.py ${WORKDIR}/CoverageOverview_basedOn_${total}_Samples.txt  > ${WORKDIR}/CoverageOverview_PerGene.txt

echo -e "Gene\tAvgCoverage\tNo of Targets\tMedian\tSD\tu10x\tu20x\tu50x\tu100x" > ${WORKDIR}/CoverageOverview_PerGene_basedOn_${total}_Samples.txt

sort -V -k1 ${WORKDIR}/CoverageOverview_PerGene.txt >> ${WORKDIR}/CoverageOverview_PerGene_basedOn_${total}_Samples.txt
echo "done, gene file can be found here: ${WORKDIR}/CoverageOverview_PerGene_basedOn_${total}_Samples.txt"
