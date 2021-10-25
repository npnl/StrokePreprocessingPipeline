#!/bin/sh

helpstr="$(basename $0) [-h] --subject DIR --output DIR [--session SES] [--model PATH] [--ignore-t1] [--ignore-t2] [--ignore-pd] [-q, --quiet] [--intermediate DIR]

where:
        -h,--help               Show this message.
        --subject DIR           BIDS-compliant subject directory.
	--session STR		BIDS session to process.
	--output DIR            Directory to place pipeline output.
	--singularity FILE	Singularity image to run ("stroke_preproc.sif").
	--intermediate DIR	Optional. Directory in which to place intermediate files.
	--qc DIR		Optional. Directory in which to gather QC images.
	--record FILE		Optional. Log file to report which subjects are complete.
	--lesion-t1 File	Optional. Path to the T1 lesion mask to co-register.
        -q, --quiet             Optional. Suppress warnings. Default: False.
"


sing_args=()
mount_args=()
while (( "$#" )); do
	case "${1}" in
		--subject)
			subject="${2}"
			mount_args+=("-B")
			mount_args+=("${2}:/${2}")
			sing_args+=("--subject")
			sing_args+=(/"${2}")
			shift 2
			;;
		--session)
			session="${2}"
			sing_args+=("--session")
			sing_args+=("${2}")
			shift 2
			;;
		--output)
			output="${2}"
			mkdir -p "${output}"
			mount_args+=("-B")
			mount_args+=("${2}:/${2}")
			sing_args+=("--output")
			sing_args+=(/"${2}")
			shift 2
			;;
		--intermediate)
			inter_path="${2}"
			mkdir -p "${inter_path}"
			mount_args+=("-B")
			mount_args+=("${2}:/${2}")
			sing_args+=("--intermediate")
			sing_args+=(/"${2}")
			shift 2
			;;
		--qc)
			qc_path="${2}"
			mkdir -p "${qc_path}"
			qc_db="${2}/mask_overlap.sql"
			qc_csv="${2}/mask_overlap.csv"
			mount_args+=("-B")
			mount_args+=("${2}:/${2}")
			sing_args+=("--qc")
			sing_args+=(/"${qc_path}")
			sing_args+=("--mask-overlap-db")
			sing_args+=("${qc_db}")
			sing_args+=("--mask-overlap-csv")
			sing_args+=("${qc_csv}")
			shift 2
			;;
		--record)
			record_path="${2}"
			touch "${record_path}"
			shift 2
			;;
		--singularity)
			singimg="${2}"
			shift 2
			;;
		--lesion-t1)
			sing_args+=("--lesion-t1")
			sing_args+=("/${2}")
			mount_args+=("-B")
			mount_args+=("${2}:/${2}")
			shift 2
			;;
		--lesion-flair)
			sing_args+=("--lesion-flair")
			sing_args+=("/${2}")
			mount_args+=("-B")
			mount_args+=("${2}:/${2}")
			shift 2
			;;
		--lesion-dwi)
			sing_args+=("--lesion-dwi")
			sing_args+=("/${2}")
			mount_args+=("-B")
			mount_args+=("${2}:/${2}")
			shift 2
			;;
	esac
done

module load singularity/3.4.1
echo "sing args: ${sing_args[@]}"
singularity run ${mount_args[@]} ${singimg} ${sing_args[@]}

if [ -n "${record_path}" ]; then
	echo "`basename ${subject}` completed" >> ${record_path}
fi
echo "Done."
