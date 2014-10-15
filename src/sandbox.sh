function make_sandbox_tag () {
	expect_vars HALCYON_DIR

	local ghc_tag sandbox_digest sandbox_hooks_hash app_label
	expect_args ghc_tag sandbox_digest sandbox_hooks_hash app_label -- "$@"

	local os
	os=$( detect_os ) || die

	local ghc_os ghc_halcyon_dir ghc_version ghc_hooks_hash
	ghc_os=$( echo_ghc_tag_os "${ghc_tag}" ) || die
	ghc_halcyon_dir=$( echo_ghc_tag_halcyon_dir "${ghc_tag}" ) || die
	ghc_version=$( echo_ghc_tag_version "${ghc_tag}" ) || die
	ghc_hooks_hash=$( echo_ghc_tag_hooks_hash "${ghc_tag}" ) || die

	if [ "${os}" != "${ghc_os}" ]; then
		die "Unexpected OS in GHC tag: ${ghc_os}"
	fi
	if [ "${HALCYON_DIR}" != "${ghc_halcyon_dir}" ]; then
		die "Unexpected HALCYON_DIR in GHC tag: ${ghc_halcyon_dir}"
	fi

	echo -e "${os}\t${HALCYON_DIR}\tghc-${ghc_version}\t${ghc_hooks_hash}\t${sandbox_digest}\t${sandbox_hooks_hash}\t${app_label}"
}


function echo_sandbox_tag_os () {
	local sandbox_tag
	expect_args sandbox_tag -- "$@"

	awk -F$'\t' '{ print $1 }' <<<"${sandbox_tag}"
}


function echo_sandbox_tag_halcyon_dir () {
	local sandbox_tag
	expect_args sandbox_tag -- "$@"

	awk -F$'\t' '{ print $2 }' <<<"${sandbox_tag}"
}


function echo_sandbox_tag_ghc_version () {
	local sandbox_tag
	expect_args sandbox_tag -- "$@"

	awk -F$'\t' '{ print $3 }' <<<"${sandbox_tag}" | sed 's/^ghc-//'
}


function echo_sandbox_tag_ghc_hooks_hash () {
	local sandbox_tag
	expect_args sandbox_tag -- "$@"

	awk -F$'\t' '{ print $4 }' <<<"${sandbox_tag}"
}


function echo_sandbox_tag_digest () {
	local sandbox_tag
	expect_args sandbox_tag -- "$@"

	awk -F$'\t' '{ print $5 }' <<<"${sandbox_tag}"
}


function echo_sandbox_tag_hooks_hash () {
	local sandbox_tag
	expect_args sandbox_tag -- "$@"

	awk -F$'\t' '{ print $6 }' <<<"${sandbox_tag}"
}


function echo_sandbox_tag_app_label () {
	local sandbox_tag
	expect_args sandbox_tag -- "$@"

	awk -F$'\t' '{ print $7 }' <<<"${sandbox_tag}"
}


function echo_sandbox_id () {
	local sandbox_tag
	expect_args sandbox_tag -- "$@"

	local sandbox_digest sandbox_hooks_hash
	sandbox_digest=$( echo_sandbox_tag_digest "${sandbox_tag}" ) || die
	sandbox_hooks_hash=$( echo_sandbox_tag_hooks_hash "${sandbox_tag}" ) || die

	echo "${sandbox_digest:0:7}${sandbox_hooks_hash:+~${sandbox_hooks_hash:0:7}}"
}


function echo_sandbox_description () {
	local sandbox_tag
	expect_args sandbox_tag -- "$@"

	local sandbox_id app_label
	sandbox_id=$( echo_sandbox_id "${sandbox_tag}" ) || die
	app_label=$( echo_sandbox_tag_app_label "${sandbox_tag}" ) || die

	echo "${sandbox_id} (${app_label})"
}


function echo_sandbox_archive () {
	local sandbox_tag
	expect_args sandbox_tag -- "$@"

	local ghc_id sandbox_id app_label
	ghc_id=$( echo_ghc_id "${sandbox_tag}" ) || die
	sandbox_id=$( echo_sandbox_id "${sandbox_tag}" ) || die
	app_label=$( echo_sandbox_tag_app_label "${sandbox_tag}" ) || die

	echo "halcyon-sandbox-ghc-${ghc_id}-${sandbox_id}-${app_label}.tar.xz"
}


function echo_sandbox_config () {
	local sandbox_tag
	expect_args sandbox_tag -- "$@"

	local ghc_id sandbox_id app_label
	ghc_id=$( echo_ghc_id "${sandbox_tag}" ) || die
	sandbox_id=$( echo_sandbox_id "${sandbox_tag}" ) || die
	app_label=$( echo_sandbox_tag_app_label "${sandbox_tag}" ) || die

	echo "halcyon-sandbox-ghc-${ghc_id}-${sandbox_id}-${app_label}.cabal.config"
}


function echo_sandbox_config_id () {
	local sandbox_config
	expect_args sandbox_config -- "$@"

	local sandbox_digest_etc
	sandbox_digest_etc="${sandbox_config#halcyon-sandbox-ghc-*-}"

	echo "${sandbox_digest_etc%%-*}"
}


function echo_sandbox_config_digest () {
	local sandbox_config
	expect_args sandbox_config -- "$@"

	local sandbox_digest_etc
	sandbox_digest_etc="${sandbox_config#halcyon-sandbox-ghc-*-}"

	echo "${sandbox_digest_etc%%[~-]*}"
}


function echo_sandbox_config_app_label () {
	local sandbox_config
	expect_args sandbox_config -- "$@"

	local app_label_etc
	app_label_etc="${sandbox_config#halcyon-sandbox-ghc-*-*-}"

	echo "${app_label_etc%.cabal.config}"
}


function echo_sandbox_config_description () {
	local sandbox_config
	expect_args sandbox_config -- "$@"

	local sandbox_id app_label
	sandbox_id=$( echo_sandbox_config_id "${sandbox_config}" ) || die
	app_label=$( echo_sandbox_config_app_label "${sandbox_config}" ) || die

	echo "${sandbox_id} (${app_label})"
}


function echo_sandbox_config_prefix () {
	local ghc_tag
	expect_args ghc_tag -- "$@"

	local ghc_id
	ghc_id=$( echo_ghc_id "${ghc_tag}" ) || die

	echo "halcyon-sandbox-ghc-${ghc_id}-"
}


function echo_sandbox_config_pattern () {
	local ghc_tag sandbox_hooks_hash
	expect_args ghc_tag sandbox_hooks_hash -- "$@"

	local ghc_id
	ghc_id=$( echo_ghc_id "${ghc_tag}" ) || die

	echo "halcyon-sandbox-ghc-${ghc_id//./\.}-.*${sandbox_hooks_hash:+~${sandbox_hooks_hash:0:7}}\.cabal\.config"
}


function echo_tmp_sandbox_config () {
	mktemp -u '/tmp/halcyon-sandbox.cabal.config.XXXXXXXXXX'
}


function hash_sandbox_hooks () {
	local hooks_dir
	expect_args hooks_dir -- "$@"

	hash_files "${hooks_dir}/"*'-sandbox-'*
}


function determine_sandbox_constraints () {
	expect_vars HALCYON_NO_WARN_CONSTRAINTS

	local app_dir
	expect_args app_dir -- "$@"
	expect_existing "${app_dir}"

	log 'Determining sandbox constraints'

	local sandbox_constraints
	if [ -f "${app_dir}/cabal.config" ]; then
		sandbox_constraints=$( detect_constraints "${app_dir}" ) || die
	else
		sandbox_constraints=$( freeze_implicit_constraints "${app_dir}" ) || die
		if ! (( ${HALCYON_NO_WARN_CONSTRAINTS} )); then
			log_warning 'Expected cabal.config with explicit constraints'
			log
			help_add_constraints "${sandbox_constraints}"
			log
		else
			echo_constraints <<<"${sandbox_constraints}" >&2 || die
		fi
	fi

	echo "${sandbox_constraints}"
}


function determine_sandbox_digest () {
	local sandbox_constraints
	expect_args sandbox_constraints -- "$@"

	log_begin 'Determining sandbox digest...'

	local sandbox_digest
	sandbox_digest=$( hash_constraints <<<"${sandbox_constraints}" ) || die

	log_end "done, ${sandbox_digest:0:7}"

	echo "${sandbox_digest}"
}


function determine_sandbox_hooks_hash () {
	local app_dir
	expect_args app_dir -- "$@"

	log_begin 'Determining sandbox hooks hash...'

	local sandbox_hooks_hash
	sandbox_hooks_hash=$( hash_sandbox_hooks "${app_dir}/.halcyon-hooks" ) || die

	if [ -z "${sandbox_hooks_hash}" ]; then
		log_end 'none'
	else
		log_end "done, ${sandbox_hooks_hash:0:7}"
	fi

	echo "${sandbox_hooks_hash}"
}


function validate_sandbox_tag () {
	local sandbox_tag
	expect_args sandbox_tag -- "$@"

	local candidate_tag
	candidate_tag=$( match_exactly_one ) || die

	if [ "${candidate_tag}" != "${sandbox_tag}" ]; then
		return 1
	fi
}


function validate_sandbox_config () {
	local sandbox_digest
	expect_args sandbox_digest -- "$@"

	local candidate_digest
	candidate_digest=$( read_constraints | hash_constraints ) || die

	if [ "${candidate_digest}" != "${sandbox_digest}" ]; then
		return 1
	fi
}


function validate_sandbox_hooks () {
	local sandbox_hooks_hash hooks_dir
	expect_args sandbox_hooks_hash hooks_dir -- "$@"

	local candidate_hooks_hash
	candidate_hooks_hash=$( hash_sandbox_hooks "${hooks_dir}" ) || die

	if [ "${candidate_hooks_hash}" != "${sandbox_hooks_hash}" ]; then
		return 1
	fi
}


function build_sandbox () {
	expect_vars HALCYON_DIR
	expect_existing "${HALCYON_DIR}/ghc/.halcyon-tag" "${HALCYON_DIR}/cabal/.halcyon-tag"

	local sandbox_constraints sandbox_tag extending_sandbox app_dir
	expect_args sandbox_constraints sandbox_tag extending_sandbox app_dir -- "$@"
	if (( ${extending_sandbox} )); then
		expect_existing "${HALCYON_DIR}/sandbox/.halcyon-tag" "${HALCYON_DIR}/sandbox/.halcyon-cabal.config"
		rm -f "${HALCYON_DIR}/sandbox/.halcyon-tag" "${HALCYON_DIR}/sandbox/.halcyon-cabal.config" || die
	else
		expect_no_existing "${HALCYON_DIR}/sandbox"
	fi
	expect_existing "${app_dir}"

	local ghc_tag sandbox_digest sandbox_description
	ghc_tag=$( <"${HALCYON_DIR}/ghc/.halcyon-tag" ) || die
	sandbox_digest=$( echo_sandbox_tag_digest "${sandbox_tag}" ) || die
	sandbox_description=$( echo_sandbox_description "${sandbox_tag}" ) || die

	log "Building sandbox ${sandbox_description}"

	if ! [ -d "${HALCYON_DIR}/sandbox" ]; then
		cabal_create_sandbox "${HALCYON_DIR}/sandbox" || die
	fi

	if [ -f "${app_dir}/.halcyon-hooks/sandbox-pre-build" ]; then
		log "Running sandbox pre-build hook"
		"${app_dir}/.halcyon-hooks/sandbox-pre-build" "${ghc_tag}" "${sandbox_tag}" "${extending_sandbox}" "${app_dir}" | die

		mkdir -p "${HALCYON_DIR}/sandbox/.halcyon-hooks" || die
		cp "${app_dir}/.halcyon-hooks/sandbox-pre-build" "${HALCYON_DIR}/sandbox/.halcyon-hooks" || die
	fi

	cabal_install_deps "${HALCYON_DIR}/sandbox" "${app_dir}" || die

	echo_constraints <<<"${sandbox_constraints}" >"${HALCYON_DIR}/sandbox/.halcyon-cabal.config" || die

	if [ -f "${app_dir}/.halcyon-hooks/sandbox-post-build" ]; then
		log "Running sandbox post-build hook"
		"${app_dir}/.halcyon-hooks/sandbox-post-build" "${ghc_tag}" "${sandbox_tag}" "${extending_sandbox}" "${app_dir}" | die

		mkdir -p "${HALCYON_DIR}/sandbox/.halcyon-hooks" || die
		cp "${app_dir}/.halcyon-hooks/sandbox-pre-build" "${HALCYON_DIR}/sandbox/.halcyon-hooks" || die
	fi

	echo "${sandbox_tag}" >"${HALCYON_DIR}/sandbox/.halcyon-tag" || die

	local sandbox_size
	sandbox_size=$( measure_recursively "${HALCYON_DIR}/sandbox" ) || die
	log "Built sandbox ${sandbox_description}, ${sandbox_size}"

	if (( ${HALCYON_NO_WARN_CONSTRAINTS} )); then
		return 0
	fi

	# NOTE: Frozen constraints should never differ before and after installation.
	# https://github.com/haskell/cabal/issues/1896

	local actual_constraints actual_digest
	actual_constraints=$( freeze_actual_constraints "${HALCYON_DIR}/sandbox" "${app_dir}" ) || die
	actual_digest=$( hash_constraints <<<"${actual_constraints}" ) || die

	if [ "${actual_digest}" != "${sandbox_digest}" ]; then
		log_warning "Actual sandbox digest is ${actual_digest:0:7}"
		log_warning 'Unexpected constraints difference:'
		echo_constraints_difference "${sandbox_constraints}" "${actual_constraints}" | quote
	fi
}


function strip_sandbox () {
	expect_vars HALCYON_DIR
	expect_existing "${HALCYON_DIR}/sandbox/.halcyon-tag"

	local sandbox_tag sandbox_description
	sandbox_tag=$( <"${HALCYON_DIR}/sandbox/.halcyon-tag" ) || die
	sandbox_description=$( echo_sandbox_description "${sandbox_tag}" ) || die

	log_begin "Stripping sandbox ${sandbox_description}..."

	find "${HALCYON_DIR}/sandbox"       \
			-type f        -and \
			\(                  \
			-name '*.so'   -or  \
			-name '*.so.*' -or  \
			-name '*.a'         \
			\)                  \
			-print0 |
		strip0 --strip-unneeded

	local sandbox_size
	sandbox_size=$( measure_recursively "${HALCYON_DIR}/sandbox" ) || die
	log_end "done, ${sandbox_size}"
}


function archive_sandbox () {
	expect_vars HALCYON_DIR HALCYON_CACHE_DIR HALCYON_NO_ARCHIVE
	expect_existing "${HALCYON_DIR}/sandbox/.halcyon-tag"

	if (( ${HALCYON_NO_ARCHIVE} )); then
		return 0
	fi

	local sandbox_tag os sandbox_archive sandbox_config sandbox_description
	sandbox_tag=$( <"${HALCYON_DIR}/sandbox/.halcyon-tag" ) || die
	os=$( echo_sandbox_tag_os "${sandbox_tag}" ) || die
	sandbox_archive=$( echo_sandbox_archive "${sandbox_tag}" ) || die
	sandbox_config=$( echo_sandbox_config "${sandbox_tag}" ) || die
	sandbox_description=$( echo_sandbox_description "${sandbox_tag}" ) || die

	log "Archiving sandbox ${sandbox_description}"

	rm -f "${HALCYON_CACHE_DIR}/${sandbox_archive}" "${HALCYON_CACHE_DIR}/${sandbox_config}" || die
	tar_archive "${HALCYON_DIR}/sandbox" "${HALCYON_CACHE_DIR}/${sandbox_archive}" || die
	cp "${HALCYON_DIR}/sandbox/.halcyon-cabal.config" "${HALCYON_CACHE_DIR}/${sandbox_config}" || die
	upload_layer "${HALCYON_CACHE_DIR}/${sandbox_archive}" "${os}" || die
	upload_layer "${HALCYON_CACHE_DIR}/${sandbox_config}" "${os}" || die
}


function restore_sandbox () {
	expect_vars HALCYON_DIR HALCYON_CACHE_DIR

	local sandbox_tag
	expect_args sandbox_tag -- "$@"

	local os sandbox_digest sandbox_hooks_hash sandbox_archive sandbox_description
	os=$( echo_sandbox_tag_os "${sandbox_tag}" ) || die
	sandbox_digest=$( echo_sandbox_tag_digest "${sandbox_tag}" ) || die
	sandbox_hooks_hash=$( echo_sandbox_tag_hooks_hash "${sandbox_tag}" ) || die
	sandbox_archive=$( echo_sandbox_archive "${sandbox_tag}" ) || die
	sandbox_description=$( echo_sandbox_description "${sandbox_tag}" ) || die

	log "Restoring sandbox ${sandbox_description}"

	if [ -f "${HALCYON_DIR}/sandbox/.halcyon-tag" ] &&
		validate_sandbox_tag "${sandbox_tag}" <"${HALCYON_DIR}/sandbox/.halcyon-tag" &&
		validate_sandbox_config "${sandbox_digest}" <"${HALCYON_DIR}/sandbox/.halcyon-cabal.config" &&
		validate_sandbox_hooks "${sandbox_hooks_hash}" "${HALCYON_DIR}/sandbox/.halcyon-hooks"
	then
		return 0
	fi
	rm -rf "${HALCYON_DIR}/sandbox" || die

	if ! [ -f "${HALCYON_CACHE_DIR}/${sandbox_archive}" ] ||
		! tar_extract "${HALCYON_CACHE_DIR}/${sandbox_archive}" "${HALCYON_DIR}/sandbox" ||
		! [ -f "${HALCYON_DIR}/sandbox/.halcyon-tag" ] ||
		! validate_sandbox_tag "${sandbox_tag}" <"${HALCYON_DIR}/sandbox/.halcyon-tag" ||
		! validate_sandbox_config "${sandbox_digest}" <"${HALCYON_DIR}/sandbox/.halcyon-cabal.config" ||
		! validate_sandbox_hooks "${sandbox_hooks_hash}" "${HALCYON_DIR}/sandbox/.halcyon-hooks"
	then
		rm -rf "${HALCYON_CACHE_DIR}/${sandbox_archive}" "${HALCYON_DIR}/sandbox" || die

		if ! download_layer "${os}" "${sandbox_archive}" "${HALCYON_CACHE_DIR}"; then
			log "Downloading ${sandbox_archive} failed"
			return 1
		fi

		if ! tar_extract "${HALCYON_CACHE_DIR}/${sandbox_archive}" "${HALCYON_DIR}/sandbox" ||
			! [ -f "${HALCYON_DIR}/sandbox/.halcyon-tag" ] ||
			! validate_sandbox_tag "${sandbox_tag}" <"${HALCYON_DIR}/sandbox/.halcyon-tag" ||
			! validate_sandbox_config "${sandbox_digest}" <"${HALCYON_DIR}/sandbox/.halcyon-cabal.config" ||
			! validate_sandbox_hooks "${sandbox_hooks_hash}" "${HALCYON_DIR}/sandbox/.halcyon-hooks"
		then
			rm -rf "${HALCYON_CACHE_DIR}/${sandbox_archive}" "${HALCYON_DIR}/sandbox" || die
			log_warning "Restoring ${sandbox_archive} failed"
			return 1
		fi
	fi
}


function activate_sandbox () {
	expect_vars HALCYON_DIR
	expect_existing "${HALCYON_DIR}/sandbox/.halcyon-tag"

	local app_dir
	expect_args app_dir -- "$@"
	expect_existing "${app_dir}"

	local sandbox_tag sandbox_description
	sandbox_tag=$( <"${HALCYON_DIR}/sandbox/.halcyon-tag" ) || die
	sandbox_description=$( echo_sandbox_description "${sandbox_tag}" ) || die

	log_begin "Activating sandbox ${sandbox_description}..."

	if [ -e "${app_dir}/cabal.sandbox.config" ] && ! [ -h "${app_dir}/cabal.sandbox.config" ]; then
		die "Expected no actual ${app_dir}/cabal.sandbox.config"
	fi

	rm -f "${app_dir}/cabal.sandbox.config" || die
	ln -s "${HALCYON_DIR}/sandbox/cabal.sandbox.config" "${app_dir}/cabal.sandbox.config" || die

	log_end 'done'
}


function deactivate_sandbox () {
	expect_vars HALCYON_DIR
	expect_existing "${HALCYON_DIR}/sandbox/.halcyon-tag"

	local app_dir
	expect_args app_dir -- "$@"
	expect_existing "${app_dir}"

	local sandbox_tag sandbox_description
	sandbox_tag=$( <"${HALCYON_DIR}/sandbox/.halcyon-tag" ) || die
	sandbox_description=$( echo_sandbox_description "${sandbox_tag}" ) || die

	log_begin "Deactivating sandbox ${sandbox_description}..."

	if [ -e "${app_dir}/cabal.sandbox.config" ] && ! [ -h "${app_dir}/cabal.sandbox.config" ]; then
		die "Expected no actual ${app_dir}/cabal.sandbox.config"
	fi

	rm -f "${app_dir}/cabal.sandbox.config" || die

	log_end 'done'
}


function locate_matched_sandbox_tag () {
	expect_vars HALCYON_DIR HALCYON_CACHE_DIR
	expect_existing "${HALCYON_DIR}/ghc/.halcyon-tag"

	local sandbox_constraints sandbox_hooks_hash
	expect_args sandbox_constraints sandbox_hooks_hash -- "$@"

	log 'Locating matched sandboxes'

	local ghc_tag os config_prefix config_pattern
	ghc_tag=$( <"${HALCYON_DIR}/ghc/.halcyon-tag" ) || die
	os=$( echo_ghc_tag_os "${ghc_tag}" ) || die
	config_prefix=$( echo_sandbox_config_prefix "${ghc_tag}" ) || die
	config_pattern=$( echo_sandbox_config_pattern "${ghc_tag}" "${sandbox_hooks_hash}" ) || die

	local matched_configs
	if ! matched_configs=$(
		list_layers "${os}/${config_prefix}" |
		sed "s:${os}/::" |
		filter_matching "^${config_pattern}$" |
		sort_naturally |
		match_at_least_one
	); then
		log 'Locating matched sandboxes failed'
		return 1
	fi

	local config
	while read -r config; do
		local digest
		digest=$( echo_sandbox_config_digest "${config}" ) || die

		if ! [ -f "${HALCYON_CACHE_DIR}/${config}" ] ||
			! validate_sandbox_config "${digest}" <"${HALCYON_CACHE_DIR}/${config}"
		then
			rm -f "${HALCYON_CACHE_DIR}/${config}" || die

			if ! download_layer "${os}" "${config}" "${HALCYON_CACHE_DIR}"; then
				log_warning "Downloading ${config} failed"
			fi

			if ! validate_sandbox_config "${digest}" <"${HALCYON_CACHE_DIR}/${config}"; then
				rm -f "${HALCYON_CACHE_DIR}/${config}" || die
				log_warning "Restoring ${config} failed"
			fi
		fi
	done <<<"${matched_configs}"

	log 'Scoring matched sandboxes'

	local matched_scores
	if ! matched_scores=$(
		local config
		while read -r config; do
			if ! [ -f "${HALCYON_CACHE_DIR}/${config}" ]; then
				continue
			fi

			local digest app_label tag description
			digest=$( echo_sandbox_config_digest "${config}" ) || die
			app_label=$( echo_sandbox_config_app_label "${config}" ) || die
			tag=$( make_sandbox_tag "${ghc_tag}" "${digest}" "${sandbox_hooks_hash}" "${app_label}" ) || die
			description=$( echo_sandbox_description "${tag}" ) || die

			local score
			if ! score=$(
				read_constraints <"${HALCYON_CACHE_DIR}/${config}" |
				sort_naturally |
				filter_valid_constraints |
				score_constraints "${sandbox_constraints}" "${description}"
			); then
				continue
			fi

			echo -e "${score} ${tag}"
		done <<<"${matched_configs}" |
			filter_not_matching '^0 ' |
			sort_naturally |
			match_at_least_one
	); then
		log 'No sandbox is matched closely enough'
		return 1
	fi

	filter_last <<<"${matched_scores}" |
		match_exactly_one |
		sed 's/^.* //'
}


function install_extended_sandbox () {
	expect_vars HALCYON_DIR HALCYON_NO_BUILD

	local sandbox_constraints sandbox_tag matched_tag app_dir
	expect_args sandbox_constraints sandbox_tag matched_tag app_dir -- "$@"

	if ! restore_sandbox "${matched_tag}"; then
		return 1
	fi

	local sandbox_id sandbox_description
	sandbox_id=$( echo_sandbox_id "${sandbox_tag}" ) || die
	sandbox_description=$( echo_sandbox_description "${sandbox_tag}" ) || die

	local matched_id matched_description
	matched_id=$( echo_sandbox_id "${matched_tag}" ) || die
	matched_description=$( echo_sandbox_description "${matched_tag}" ) || die

	if [ "${matched_id}" = "${sandbox_id}" ]; then
		log "Using matched sandbox ${matched_description} as sandbox ${sandbox_description}"

		echo "${sandbox_tag}" >"${HALCYON_DIR}/sandbox/.halcyon-tag" || die
		archive_sandbox || die
		activate_sandbox "${app_dir}" || die
		return 0
	fi

	! (( ${HALCYON_NO_BUILD} )) || return 1

	log "Extending matched sandbox ${matched_description} to sandbox ${sandbox_description}"

	local extending_sandbox=1
	build_sandbox "${sandbox_constraints}" "${sandbox_tag}" "${extending_sandbox}" "${app_dir}" || die
	strip_sandbox || die
	archive_sandbox || die
	activate_sandbox "${app_dir}" || die
}


function install_sandbox () {
	expect_vars HALCYON_DIR HALCYON_FORCE_BUILD_ALL HALCYON_FORCE_BUILD_SANDBOX HALCYON_NO_BUILD
	expect_existing "${HALCYON_DIR}/ghc/.halcyon-tag"

	local app_dir
	expect_args app_dir -- "$@"

	local ghc_tag sandbox_constraints sandbox_digest sandbox_hooks_hash sandbox_tag app_label
	ghc_tag=$( <"${HALCYON_DIR}/ghc/.halcyon-tag" ) || die
	sandbox_constraints=$( determine_sandbox_constraints "${app_dir}" ) || die
	sandbox_digest=$( determine_sandbox_digest "${sandbox_constraints}" ) || die
	sandbox_hooks_hash=$( determine_sandbox_hooks_hash "${app_dir}" ) || die
	app_label=$( detect_app_label "${app_dir}" ) || die
	sandbox_tag=$( make_sandbox_tag "${ghc_tag}" "${sandbox_digest}" "${sandbox_hooks_hash}" "${app_label}" ) || die

	if ! (( ${HALCYON_FORCE_BUILD_ALL} )) &&
		! (( ${HALCYON_FORCE_BUILD_SANDBOX} )) &&
		restore_sandbox "${sandbox_tag}"
	then
		activate_sandbox "${app_dir}" || die
		return 0
	fi

	local matched_tag
	if ! (( ${HALCYON_FORCE_BUILD_ALL} )) &&
		! (( ${HALCYON_FORCE_BUILD_SANDBOX} )) &&
		matched_tag=$( locate_matched_sandbox_tag "${sandbox_constraints}" "${sandbox_hooks_hash}" ) &&
		install_extended_sandbox "${sandbox_constraints}" "${sandbox_tag}" "${matched_tag}" "${app_dir}"
	then
		return 0
	fi

	! (( ${HALCYON_NO_BUILD} )) || return 1

	local extending_sandbox=0
	build_sandbox "${sandbox_constraints}" "${sandbox_tag}" "${extending_sandbox}" "${app_dir}" || die
	strip_sandbox || die
	archive_sandbox || die
	activate_sandbox "${app_dir}" || die
}
