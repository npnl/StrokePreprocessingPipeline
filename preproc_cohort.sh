#!/bin/bash
helpstr="$(basename $0) [-h, --help] [--qc DIR] [--record FILE] [--sge_output DIR] [--sge_error DIR] --singularity FILE --cohort DIR --subject DIR --lesion DIR --output DIR

where:
	-h, --help		      Show this message.
	--qc DIR        		Optional. Store copy of QC results in DIR.
	--record FILE		    Optional. Report which subjects have been completed.
	-q, --quiet		      Optional. If set, minimize printed messages.
	--sge_output DIR	  Optional. Directory to store SGE output files.
	--sge_error DIR		  Optional. Directory to store SGE error files.
	--override		      Optional. If set, will run subjects within the cohort that have lesion masks instead of ignoring entire cohort.
	--singularity FILE	Path to Singularity container to run.
	--cohort DIR		    Path to top-level BIDS directory containing a cohort. Either --cohort or --subject must be defined.
	--subject DIR		    Path to individual subject in a BIDS directory. Either --cohort or --subject must be defined.
	--lesion DIR		    Path to lesion mask data.
	--output DIR		    Path to place output.
"

# Constants
lesion_name='echo sub-${subject_id}_ses-${ses_id}_space-orig_label-L_desc-T1lesion_mask.nii.gz'


# Submits jobs based on input
arg_list=()
sge_args=()
cohort_flag=0
subject_flag=0
quiet=0
override=0
present=`pwd`
# SGE doesn't like paths

while (( "$#" )); do
	case "${1}" in
		-h|--help)
			echo "${helpstr}"
			exit 0
			;;
		-q|--quiet)
			quiet=1
			shift 1
			;;
		--subject)
			subject="${2}"
			subject_flag=1
			shift 2
			;;
		--output)
			output="${2}"
			arg_list+=("${1}")
			arg_list+=("${2}")
			shift 2
			;;
		--lesion)
			lesion="${2}"
			# arg_list+=("${1}")
			# arg_list+=("${2}")
			shift 2
			;;
		--intermediate)
			intermediate="${2}"
			arg_list+=("${1}")
			arg_list+=("${2}")
			shift 2
			;;
		--qc)
			qc_path="${2}"
			arg_list+=("${1}")
			arg_list+=("${2}")
			shift 2
			;;
		--override)
			override=1
			shift 1
			;;
		--record)
			record_path="${2}"
			arg_list+=("${1}")
			arg_list+=("${2}")
			shift 2
			;;
		--singularity)
			singimg="${2}"
			arg_list+=("${1}")
			arg_list+=("${2}")
			shift 2
			;;
		--cohort)
			cohort="${2}"
			cohort_flag=1
			shift 2
			;;
		--sge_output)
			sge_args+=("-o")
			sge_args+=("${2}")
			shift 2
			;;
		--sge_error)
			sge_args+=("-e")
			sge_args+=("${2}")
			shift 2
			;;
		-*)
			echo "Unrecognized option: ${1}"
			exit 1
			;;
	esac
done

qecho () {
	if [ "${quiet}" -eq 0 ]; then
		echo "$@"
	fi
}

# For every subject, check if lesion mask exists in ${lesion}
# Get list of subjects
if [ "${cohort_flag}" -eq 1 ]; then
	subject_checklist=()
	if [ -n "${cohort}" ]; then
		subject_checklist=(`ls -1d ${cohort}/sub-*`)
	elif [ -n "${subject}" ]; then
		subject_checklist=(${subject})
	else
		>&2 echo "Either --cohort or --subject must be defined."
		exit 1
	fi

	# Construct expected lesionmask name (sub-ID_ses-SES_desc-lesionmask
	subject_process=()
	subject_omit=()
	qsub_cmd_list=()
	for sub in ${subject_checklist[@]}; do
		if [[ ${sub} =~ .*sub-(.+) ]]; then
			subject_id="${BASH_REMATCH[1]}"
		else
			continue
		fi
		# Inside subject dir, check sessions
		#echo "sub: ${sub}"
		#echo `ls "${sub}"`
		ses_list=(`ls -1d ${sub}/ses-*`)
		for ses in ${ses_list[@]}; do
			if [[ ${ses} =~ .*ses-(.+) ]]; then
				ses_id="${BASH_REMATCH[1]}"
			else
				continue
			fi
			# If file exists, add subject to subjects to process
			lesion_path="${lesion}/sub-${subject_id}/ses-${ses_id}/anat/"
			lesion_file=`eval ${lesion_name}`
			lesion_args=()
			lesion_args+=('--lesion-t1')
			lesion_args+=("${lesion_path}/${lesion_file}")
      if [ -f "${lesion_path}/${lesion_file}" ]; then
        subject_process+=("${sub}")
				q="qsub -cwd -N ${subject_id} -q compute7.q -l h_vmem=12G ${sge_args[@]} worker_preproc.sh --subject `readlink -f ${sub}` --session ${ses_id} ${lesion_args[@]} ${arg_list[@]}"
				qsub_cmd_list+=("${q}")
			else
				subject_omit+=("Subject: ${sub} --- Session: ${ses} --- Missing: ${lesion_file}")
			fi
		done
	done

	qecho "Found ${#subject_checklist[@]} subjects - ${#subject_process[@]} to process - ${#subject_omit[@]} to omit"
	if [[ "${override}" -eq 0 && ${#subject_omit[@]} -gt 0 ]]; then
		>&2 echo "Cohort is not ready; ${#subject_omit[@]} without lesion masks:"
		for sub in "${subject_omit[@]}"; do
		  >&2 echo "${sub}"
    done
		exit 1
	fi

	#for sub in ${subject_process[@]}; do
	for qind in `seq 0 $((${#qsub_cmd_list[@]}-1))`; do
#		echo "command: ${qsub_cmd_list[${qind}]}"
		q="${qsub_cmd_list[${qind}]}"
		eval ${q}
	done
elif [ "${subject_flag}" -eq 1 ]; then
	qsub -cwd -N "${subject}" -q compute7.q -l h_vmem=12G ${sge_args[@]} worker_preproc.sh --subject ${subject} ${arg_list}
	echo "Preprocessing: ${sub}"
	echo "arg_list: ${arg_list[@]}"
fi
