#!/bin/sh

sing_args=()
mount_args=()
while (( "$#" )); do
	case "${1}" in
		--subject)
			subject="${2}"
			mount_args+=("-B")
			mount_args+=("${2}:/${2}")
			sing_args+=("--subject")
			sing_args+=(/${2})
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
			sing_args+=(/${2})
			shift 2
			;;
		--intermediate)
			inter_path="${2}"
			mkdir -p "${inter_path}"
			mount_args+=("-B")
			mount_args+=("${2}:/${2}")
			sing_args+=("--intermediate")
			sing_args+=(/${2})
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
			sing_args+=(/${qc_path})
			sing_args+=("--mask-overlap-db")
			sing_args+=("${qc_db}")
			sing_args+=("--mask-overlap-csv")
			sing_args+=("${qc_csv}")
			shift 2
			;;
		--record)
			record_path="${2}"
			touch ${record_path}
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
#--subject R002/sub-r002s008 --output civet_bids_output_02 --intermediate civet_bids_intermediate_02 --qc civet_bids_qc_02
