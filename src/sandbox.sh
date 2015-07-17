create_sandbox_tag () {
	local label constraints_hash \
		ghc_version ghc_magic_hash \
		cabal_version cabal_magic_hash \
		sandbox_magic_hash
	expect_args label constraints_hash \
		ghc_version ghc_magic_hash \
		cabal_version cabal_magic_hash \
		sandbox_magic_hash -- "$@"

	create_tag '' "${label}" '' "${constraints_hash}" '' \
		"${ghc_version}" "${ghc_magic_hash}" \
		"${cabal_version}" "${cabal_magic_hash}" '' '' \
		"${sandbox_magic_hash}"
}


detect_sandbox_tag () {
	local tag_file
	expect_args tag_file -- "$@"

	local tag_pattern
	tag_pattern=$(
		create_sandbox_tag '.*' '.*' \
			'.*' '.*' \
			'.*' '.*' \
			'.*'
	)

	local tag
	if ! tag=$( detect_tag "${tag_file}" "${tag_pattern}" ); then
		log_error 'Failed to detect sandbox tag'
		return 1
	fi

	echo "${tag}"
}


derive_sandbox_tag () {
	local tag
	expect_args tag -- "$@"

	local label constraints_hash \
		ghc_version ghc_magic_hash \
		cabal_version cabal_magic_hash \
		sandbox_magic_hash
	label=$( get_tag_label "${tag}" )
	constraints_hash=$( get_tag_constraints_hash "${tag}" )
	ghc_version=$( get_tag_ghc_version "${tag}" )
	ghc_magic_hash=$( get_tag_ghc_magic_hash "${tag}" )
	cabal_version=$( get_tag_cabal_version "${tag}" )
	cabal_magic_hash=$( get_tag_cabal_magic_hash "${tag}" )
	sandbox_magic_hash=$( get_tag_sandbox_magic_hash "${tag}" )

	create_sandbox_tag "${label}" "${constraints_hash}" \
		"${ghc_version}" "${ghc_magic_hash}" \
		"${cabal_version}" "${cabal_magic_hash}" \
		"${sandbox_magic_hash}"
}


derive_matching_sandbox_tag () {
	local tag label constraints_hash
	expect_args tag label constraints_hash -- "$@"

	local ghc_version ghc_magic_hash \
		cabal_version cabal_magic_hash \
		sandbox_magic_hash
	ghc_version=$( get_tag_ghc_version "${tag}" )
	ghc_magic_hash=$( get_tag_ghc_magic_hash "${tag}" )
	cabal_version=$( get_tag_cabal_version "${tag}" )
	cabal_magic_hash=$( get_tag_cabal_magic_hash "${tag}" )
	sandbox_magic_hash=$( get_tag_sandbox_magic_hash "${tag}" )

	create_sandbox_tag "${label}" "${constraints_hash}" \
		"${ghc_version}" "${ghc_magic_hash}" \
		"${cabal_version}" "${cabal_magic_hash}" \
		"${sandbox_magic_hash}"
}


format_sandbox_id () {
	local tag
	expect_args tag -- "$@"

	local constraints_hash sandbox_magic_hash
	constraints_hash=$( get_tag_constraints_hash "${tag}" )
	sandbox_magic_hash=$( get_tag_sandbox_magic_hash "${tag}" )

	echo "${constraints_hash:0:7}${sandbox_magic_hash:+.${sandbox_magic_hash:0:7}}"
}


format_sandbox_description () {
	local tag
	expect_args tag -- "$@"

	local label sandbox_id
	label=$( get_tag_label "${tag}" )
	sandbox_id=$( format_sandbox_id "${tag}" )

	echo "${label} (${sandbox_id})"
}


format_sandbox_archive_name () {
	local tag
	expect_args tag -- "$@"

	local label sandbox_id
	label=$( get_tag_label "${tag}" )
	sandbox_id=$( format_sandbox_id "${tag}" )

	echo "halcyon-sandbox-${sandbox_id}-${label}.tar.gz"
}


format_sandbox_constraints_file_name () {
	local tag
	expect_args tag -- "$@"

	local label sandbox_id
	label=$( get_tag_label "${tag}" )
	sandbox_id=$( format_sandbox_id "${tag}" )

	echo "halcyon-sandbox-${sandbox_id}-${label}.constraints"
}


format_full_sandbox_constraints_file_name_pattern () {
	local tag
	expect_args tag -- "$@"

	local sandbox_id
	sandbox_id=$( format_sandbox_id "${tag}" )

	echo "halcyon-sandbox-${sandbox_id}-.*.constraints"
}


format_partial_sandbox_constraints_file_name_pattern () {
	local tag
	expect_args tag -- "$@"

	local sandbox_magic_hash
	sandbox_magic_hash=$( get_tag_sandbox_magic_hash "${tag}" )

	echo "halcyon-sandbox-.*${sandbox_magic_hash:+.${sandbox_magic_hash:0:7}}-.*.constraints"
}


format_sandbox_common_file_name_prefix () {
	echo "halcyon-sandbox-"
}


format_sandbox_common_file_name_pattern () {
	local tag
	expect_args tag -- "$@"

	local label
	label=$( get_tag_label "${tag}" )

	echo "halcyon-sandbox-.*-${label}.(tar.gz|constraints)"
}


format_sandbox_constraints_file_name_label () {
	local constraints_name
	expect_args constraints_name -- "$@"

	local label_etc
	label_etc="${constraints_name#halcyon-sandbox-*-}"

	echo "${label_etc%.constraints}"
}


hash_sandbox_magic () {
	local source_dir
	expect_args source_dir -- "$@"

	local sandbox_magic_hash
	if ! sandbox_magic_hash=$( hash_tree "${source_dir}/.halcyon" \( -path './ghc*' -or -path './sandbox*' \) ); then
		log_error 'Failed to hash sandbox magic files'
		return 1
	fi

	echo "${sandbox_magic_hash}"
}


copy_sandbox_magic () {
	expect_vars HALCYON_BASE

	local source_dir
	expect_args source_dir -- "$@"

	expect_existing "${HALCYON_BASE}/sandbox" || return 1

	local sandbox_magic_hash
	sandbox_magic_hash=$( hash_sandbox_magic "${source_dir}" ) || return 1
	if [[ -z "${sandbox_magic_hash}" ]]; then
		return 0
	fi

	local file
	find_tree "${source_dir}/.halcyon" -type f \( -path './ghc*' -or -path './sandbox*' \) |
		while read -r file; do
			copy_file "${source_dir}/.halcyon/${file}" \
				"${HALCYON_BASE}/sandbox/.halcyon/${file}" || return 1
		done || return 0
}


add_sandbox_sources () {
	expect_vars HALCYON_BASE

	local source_dir
	expect_args source_dir -- "$@"

	if [[ ! -f "${source_dir}/.halcyon/sandbox-sources" ]]; then
		return 0
	fi

	local sandbox_sources sources_dir
	sandbox_sources=$( <"${source_dir}/.halcyon/sandbox-sources" ) || true
	sources_dir="${HALCYON_BASE}/sandbox/.halcyon-sandbox-sources"

	local name
	git_acquire_all "${source_dir}" "${sandbox_sources}" "${sources_dir}" |
		while read -r name; do
			log "Adding sandbox source: ${name}"

			sandboxed_cabal_do "${source_dir}" sandbox add-source \
				"${sources_dir}/${name}" || return 1
		done || return 0
}


install_sandbox_extra_os_packages () {
	expect_vars HALCYON_BASE

	local tag source_dir
	expect_args tag source_dir -- "$@"

	if [[ ! -f "${source_dir}/.halcyon/sandbox-extra-os-packages" ]]; then
		return 0
	fi

	local extra_packages
	extra_packages=$( <"${source_dir}/.halcyon/sandbox-extra-os-packages" ) || true

	log 'Installing sandbox extra OS packages'

	if ! install_platform_packages "${extra_packages}" "${HALCYON_BASE}/sandbox"; then
		log_error 'Failed to install sandbox extra OS packages'
		return 1
	fi
}


install_sandbox_extra_apps () {
	expect_vars HALCYON_BASE

	local tag source_dir
	expect_args tag source_dir -- "$@"

	if [[ ! -f "${source_dir}/.halcyon/sandbox-extra-apps" ]]; then
		return 0
	fi

	local ghc_version ghc_magic_hash
	ghc_version=$( get_tag_ghc_version "${tag}" )
	ghc_magic_hash=$( get_tag_ghc_magic_hash "${tag}" )

	local cabal_version cabal_magic_hash cabal_remote_repo
	cabal_version=$( get_tag_cabal_version "${tag}" )
	cabal_magic_hash=$( get_tag_cabal_magic_hash "${tag}" )
	cabal_remote_repo=$( get_tag_cabal_remote_repo "${tag}" )

	local extra_constraints
	extra_constraints="${source_dir}/.halcyon/sandbox-extra-apps-constraints"

	local -a opts_a
	opts_a=()
	opts_a+=( --root='/' )
	opts_a+=( --prefix="${HALCYON_BASE}/sandbox" )
	opts_a+=( --ghc-version="${ghc_version}" )
	opts_a+=( --cabal-version="${cabal_version}" )
	opts_a+=( --cabal-remote-repo="${cabal_remote_repo}" )
	[[ -e "${extra_constraints}" ]] && opts_a+=( --constraints="${extra_constraints}" )

	log 'Installing sandbox extra apps'

	local extra_app index
	index=0
	while read -r extra_app; do
		local thing
		if [[ -d "${source_dir}/${extra_app}" ]]; then
			thing="${source_dir}/${extra_app}"
		else
			thing="${extra_app}"
		fi

		index=$(( index + 1 ))
		if (( index > 1 )); then
			log
		fi

		# NOTE: Returns 2 if build is needed.
		HALCYON_INTERNAL_RECURSIVE=1 \
		HALCYON_INTERNAL_GHC_MAGIC_HASH="${ghc_magic_hash}" \
		HALCYON_INTERNAL_CABAL_MAGIC_HASH="${cabal_magic_hash}" \
		HALCYON_INTERNAL_NO_COPY_LOCAL_SOURCE=1 \
			halcyon install "${opts_a[@]}" "${thing}" 2>&1 | quote || return
	done <"${source_dir}/.halcyon/sandbox-extra-apps" || return 0
}


build_sandbox_dir () {
	expect_vars HALCYON_BASE \
		HALCYON_SANDBOX_NO_REMOVE_DOC HALCYON_SANDBOX_NO_STRIP

	local tag source_dir constraints must_create
	expect_args tag source_dir constraints must_create -- "$@"

	local ghc_version cabal_version
	ghc_version=$( get_tag_ghc_version "${tag}" )
	cabal_version=$( get_tag_cabal_version "${tag}" )

	if (( must_create )); then
		if ! rm -rf "${HALCYON_BASE}/sandbox"; then
			log_error 'Failed to remove sandbox directory'
			return 1
		fi
	else
		expect_existing "${HALCYON_BASE}/sandbox/.halcyon-tag" \
			"${HALCYON_BASE}/sandbox/.halcyon-constraints" || return 1
	fi
	expect_existing "${source_dir}" || return 1

	log 'Building sandbox directory'

	if (( must_create )); then
		log 'Creating sandbox'

		if ! cabal_create_sandbox; then
			log_error 'Failed to create sandbox'
			return 1
		fi
	fi

	if ! add_sandbox_sources "${source_dir}"; then
		log_error 'Failed to add sandbox sources'
		return 1
	fi

	# NOTE: Returns 2 if build is needed.
	install_sandbox_extra_apps "${tag}" "${source_dir}" || return

	install_sandbox_extra_os_packages "${tag}" "${source_dir}" || return 1

	if [[ -f "${source_dir}/.halcyon/sandbox-pre-build-hook" ]]; then
		log 'Executing sandbox pre-build hook'
		if ! HALCYON_INTERNAL_RECURSIVE=1 \
			HALCYON_GHC_VERSION="${ghc_version}" \
			HALCYON_CABAL_VERSION="${cabal_version}" \
			"${source_dir}/.halcyon/sandbox-pre-build-hook" \
				"${tag}" "${source_dir}" "${constraints}" 2>&1 | quote
		then
			log_error 'Failed to execute sandbox pre-build hook'
			return 1
		fi
		log 'Sandbox pre-build hook executed'
	fi

	local -a opts_a
	opts_a=()
	opts_a+=( --dependencies-only )
	[[ -e "${HALCYON_BASE}/sandbox/include" ]] && opts_a+=( --extra-include-dirs="${HALCYON_BASE}/sandbox/include" )
	[[ -e "${HALCYON_BASE}/sandbox/usr/include" ]] && opts_a+=( --extra-include-dirs="${HALCYON_BASE}/sandbox/usr/include" )
	[[ -e "${HALCYON_BASE}/sandbox/lib" ]] && opts_a+=( --extra-lib-dirs="${HALCYON_BASE}/sandbox/lib" )
	[[ -e "${HALCYON_BASE}/sandbox/usr/lib" ]] && opts_a+=( --extra-lib-dirs="${HALCYON_BASE}/sandbox/usr/lib" )

	case "${HALCYON_INTERNAL_PLATFORM}" in
	'linux-amzn-'*|'linux-centos-'*|'linux-fedora-'*|'linux-rhel-'*)
		[[ -e "${HALCYON_BASE}/sandbox/lib64" ]] && opts_a+=( --extra-lib-dirs="${HALCYON_BASE}/sandbox/lib64" )
		[[ -e "${HALCYON_BASE}/sandbox/usr/lib64" ]] && opts_a+=( --extra-lib-dirs="${HALCYON_BASE}/sandbox/usr/lib64" )
		;;
	'linux-debian-'*'-i386'|'linux-ubuntu-'*'-i386')
		[[ -e "${HALCYON_BASE}/sandbox/include/i386-linux-gnu" ]] && opts_a+=( --extra-include-dirs="${HALCYON_BASE}/sandbox/include/i386-linux-gnu" )
		[[ -e "${HALCYON_BASE}/sandbox/usr/include/i386-linux-gnu" ]] && opts_a+=( --extra-include-dirs="${HALCYON_BASE}/sandbox/usr/include/i386-linux-gnu" )
		[[ -e "${HALCYON_BASE}/sandbox/lib/i386-linux-gnu" ]] && opts_a+=( --extra-lib-dirs="${HALCYON_BASE}/sandbox/lib/i386-linux-gnu" )
		[[ -e "${HALCYON_BASE}/sandbox/usr/lib/i386-linux-gnu" ]] && opts_a+=( --extra-lib-dirs="${HALCYON_BASE}/sandbox/usr/lib/i386-linux-gnu" )
		;;
	'linux-debian-'*'-x86_64'|'linux-ubuntu-'*'-x86_64')
		[[ -e "${HALCYON_BASE}/sandbox/include/x86_64-linux-gnu" ]] && opts_a+=( --extra-include-dirs="${HALCYON_BASE}/sandbox/include/x86_64-linux-gnu" )
		[[ -e "${HALCYON_BASE}/sandbox/usr/include/x86_64-linux-gnu" ]] && opts_a+=( --extra-include-dirs="${HALCYON_BASE}/sandbox/usr/include/x86_64-linux-gnu" )
		[[ -e "${HALCYON_BASE}/sandbox/lib/x86_64-linux-gnu" ]] && opts_a+=( --extra-lib-dirs="${HALCYON_BASE}/sandbox/lib/x86_64-linux-gnu" )
		[[ -e "${HALCYON_BASE}/sandbox/usr/lib/x86_64-linux-gnu" ]] && opts_a+=( --extra-lib-dirs="${HALCYON_BASE}/sandbox/usr/lib/x86_64-linux-gnu" )
	esac

	if [[ -f "${source_dir}/.halcyon/sandbox-extra-configure-flags" ]]; then
		set -f; IFS=$'\n'
		opts_a=( $( <"${source_dir}/.halcyon/sandbox-extra-configure-flags" ) ) || true
		set +f; unset IFS
	fi

	log 'Building sandbox'

	local built_size
	if ! sandboxed_cabal_do "${source_dir}" install "${opts_a[@]}" 2>&1 | quote ||
		! copy_sandbox_magic "${source_dir}" ||
		! built_size=$( get_size "${HALCYON_BASE}/sandbox" )
	then
		log_error 'Failed to build sandbox'
		return 1
	fi
	log "Sandbox built, ${built_size}"

	if ! format_constraints <<<"${constraints}" \
		>"${HALCYON_BASE}/sandbox/.halcyon-constraints"
	then
		log_error 'Failed to prepare sandbox directory'
		return 1
	fi

	if [[ -f "${source_dir}/.halcyon/sandbox-post-build-hook" ]]; then
		log 'Executing sandbox post-build hook'
		if ! HALCYON_INTERNAL_RECURSIVE=1 \
			HALCYON_GHC_VERSION="${ghc_version}" \
			HALCYON_CABAL_VERSION="${cabal_version}" \
			"${source_dir}/.halcyon/sandbox-post-build-hook" \
				"${tag}" "${source_dir}" "${constraints}" 2>&1 | quote
		then
			log_error 'Failed to execute sandbox post-build hook'
			return 1
		fi
		log 'Sandbox post-build hook executed'
	fi

	if ! (( HALCYON_SANDBOX_NO_REMOVE_DOC )) &&
		[[ -d "${HALCYON_BASE}/sandbox/logs" || -d "${HALCYON_BASE}/sandbox/share/doc" ]]
	then
		log_indent_begin 'Removing documentation from sandbox directory...'

		local trimmed_size
		if ! rm -rf "${HALCYON_BASE}/sandbox/logs" "${HALCYON_BASE}/sandbox/share/doc" ||
			! trimmed_size=$( get_size "${HALCYON_BASE}/sandbox" )
		then
			log_indent_end 'error'
			return 1
		fi
		log_indent_end "done, ${trimmed_size}"
	fi

	if ! (( HALCYON_SANDBOX_NO_STRIP )); then
		log_indent_begin 'Stripping sandbox directory...'

		local stripped_size
		if ! strip_tree "${HALCYON_BASE}/sandbox" ||
			! stripped_size=$( get_size "${HALCYON_BASE}/sandbox" )
		then
			log_indent_end 'error'
			return 1
		fi
		log_indent_end "done, ${stripped_size}"
	fi

	if ! derive_sandbox_tag "${tag}" >"${HALCYON_BASE}/sandbox/.halcyon-tag"; then
		log_error 'Failed to write sandbox tag'
		return 1
	fi
}


archive_sandbox_dir () {
	expect_vars HALCYON_BASE HALCYON_CACHE HALCYON_NO_ARCHIVE \
		HALCYON_INTERNAL_PLATFORM

	if (( HALCYON_NO_ARCHIVE )); then
		return 0
	fi

	expect_existing "${HALCYON_BASE}/sandbox/.halcyon-tag" \
		"${HALCYON_BASE}/sandbox/.halcyon-constraints" || return 1

	local sandbox_tag ghc_id archive_name constraints_name
	sandbox_tag=$( detect_sandbox_tag "${HALCYON_BASE}/sandbox/.halcyon-tag" ) || return 1
	ghc_id=$( format_ghc_id "${sandbox_tag}" )
	archive_name=$( format_sandbox_archive_name "${sandbox_tag}" )
	constraints_name=$( format_sandbox_constraints_file_name "${sandbox_tag}" )

	log 'Archiving sandbox directory'

	create_cached_archive "${HALCYON_BASE}/sandbox" "${archive_name}" || return 1

	if ! copy_file "${HALCYON_BASE}/sandbox/.halcyon-constraints" \
		"${HALCYON_CACHE}/${constraints_name}"
	then
		log_error 'Failed to cache file'
		return 1
	fi

	upload_cached_file "${HALCYON_INTERNAL_PLATFORM}/ghc-${ghc_id}" "${archive_name}" || return 1
	upload_cached_file "${HALCYON_INTERNAL_PLATFORM}/ghc-${ghc_id}" "${constraints_name}" || return 1

	local common_prefix common_pattern
	common_prefix=$( format_sandbox_common_file_name_prefix )
	common_pattern=$( format_sandbox_common_file_name_pattern "${sandbox_tag}" )

	delete_matching_private_stored_files "${HALCYON_INTERNAL_PLATFORM}/ghc-${ghc_id}" "${common_prefix}" "${common_pattern}" "(${archive_name}|${constraints_name})" || return 1
}


validate_sandbox_dir () {
	expect_vars HALCYON_BASE

	local tag
	expect_args tag -- "$@"

	local sandbox_tag candidate_tag
	sandbox_tag=$( derive_sandbox_tag "${tag}" )
	candidate_tag=$( detect_tag "${HALCYON_BASE}/sandbox/.halcyon-tag" "${sandbox_tag//./\.}" ) || return 1

	if [[ ! -f "${HALCYON_BASE}/sandbox/cabal.sandbox.config" ]]; then
		return 1
	fi

	echo "${candidate_tag}"
}


restore_sandbox_dir () {
	expect_vars HALCYON_BASE \
		HALCYON_INTERNAL_PLATFORM

	local tag
	expect_args tag -- "$@"

	local ghc_id archive_name
	ghc_id=$( format_ghc_id "${tag}" )
	archive_name=$( format_sandbox_archive_name "${tag}" )

	if validate_sandbox_dir "${tag}" >'/dev/null'; then
		log 'Using existing sandbox directory'

		touch_cached_file "${archive_name}"
		return 0
	fi
	rm -rf "${HALCYON_BASE}/sandbox" || true

	log 'Restoring sandbox directory'

	if ! extract_cached_archive_over "${archive_name}" "${HALCYON_BASE}/sandbox" ||
		! validate_sandbox_dir "${tag}" >'/dev/null'
	then
		rm -rf "${HALCYON_BASE}/sandbox" || true
		cache_stored_file "${HALCYON_INTERNAL_PLATFORM}/ghc-${ghc_id}" "${archive_name}" || return 1

		if ! extract_cached_archive_over "${archive_name}" "${HALCYON_BASE}/sandbox" ||
			! validate_sandbox_dir "${tag}" >'/dev/null'
		then
			rm -rf "${HALCYON_BASE}/sandbox" || true

			log_warning 'Failed to restore sandbox directory'
			return 1
		fi
	else
		touch_cached_file "${archive_name}"
	fi
}


get_sandbox_package_db () {
	expect_vars HALCYON_BASE

	filter_matching '^package-db: ' <"${HALCYON_BASE}/sandbox/cabal.sandbox.config" |
		match_exactly_one |
		awk '{ print $2 }' || return 1
}


recache_sandbox_package_db () {
	local package_db
	if ! package_db=$( get_sandbox_package_db ) ||
		! ghc-pkg recache --package-db="${package_db}" 2>&1 | quote
	then
		log_warning 'Failed to recache sandbox package database'
	fi
}


install_matching_sandbox_dir () {
	expect_vars HALCYON_BASE

	local tag source_dir constraints matching_tag
	expect_args tag source_dir constraints matching_tag -- "$@"

	local constraints_hash matching_hash matching_description
	constraints_hash=$( get_tag_constraints_hash "${tag}" )
	matching_hash=$( get_tag_constraints_hash "${matching_tag}" )
	matching_description=$( format_sandbox_description "${matching_tag}" )

	if [[ "${matching_hash}" == "${constraints_hash}" ]]; then
		log "Using fully-matching sandbox directory: ${matching_description}"

		HALCYON_NO_UPLOAD=1 \
			restore_sandbox_dir "${matching_tag}" || return 1
		recache_sandbox_package_db

		if ! derive_sandbox_tag "${tag}" >"${HALCYON_BASE}/sandbox/.halcyon-tag"; then
			log_error 'Failed to write sandbox tag'
			return 1
		fi
		return 0
	fi

	log "Using partially-matching sandbox directory: ${matching_description}"

	HALCYON_NO_UPLOAD=1 \
		restore_sandbox_dir "${matching_tag}" || return 1
	recache_sandbox_package_db

	local must_create
	must_create=0
	build_sandbox_dir "${tag}" "${source_dir}" "${constraints}" "${must_create}" || return 1
}


install_sandbox_dir () {
	expect_vars HALCYON_NO_BUILD HALCYON_NO_BUILD_DEPENDENCIES \
		HALCYON_SANDBOX_REBUILD

	local tag source_dir constraints
	expect_args tag source_dir constraints -- "$@"

	if ! (( HALCYON_SANDBOX_REBUILD )); then
		if restore_sandbox_dir "${tag}"; then
			recache_sandbox_package_db
			return 0
		fi

		# NOTE: If Halcyon fails to build the sandbox on top of a
		# matching sandbox, it will attempt to build the sandbox
		# from scratch.
		local matching_tag
		if matching_tag=$( match_sandbox_dir "${tag}" "${constraints}" ) &&
			install_matching_sandbox_dir "${tag}" "${source_dir}" "${constraints}" "${matching_tag}"
		then
			archive_sandbox_dir || return 1
			return 0
		fi

		# NOTE: Returns 2 if build is needed.
		if (( HALCYON_NO_BUILD )) || (( HALCYON_NO_BUILD_DEPENDENCIES )); then
			log_error 'Cannot build sandbox directory'
			return 2
		fi
	fi

	# NOTE: Returns 2 if build is needed.
	local must_create
	must_create=1
	build_sandbox_dir "${tag}" "${source_dir}" "${constraints}" "${must_create}" || return
	archive_sandbox_dir || return 1
}
