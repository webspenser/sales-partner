#!/usr/bin/env bash
# This agent's guard policies, run through the Agent Standard engine.
set -uo pipefail
cd "$(dirname "$0")/.."
source tests/lib.sh
E=hooks/guard_policy.py
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT

check() { # check <rc> <label> <policy> <tool_name> <tool_input> [text] [bindings]; SM=<server_match> as guard.sh passes it
  local out rc
  out=$(printf '{"tool_name":"%s","tool_input":%s}' "$4" "$5" | python3 -B "$E" "$3" "${7:--}" "sales-partner guard policy" ${SM:+"$SM"} 2>&1); rc=$?
  if [ "$rc" -eq "$1" ] && { [ -z "${6:-}" ] || printf '%s\n' "$out" | grep -qF -- "$6"; }; then _report ok "$2"; else _report no "$2 (rc=$rc): $out"; fi
}
for p in capabilities/*/tools/*/guard.yaml; do
  python3 -B "$E" --check "$p" >/dev/null && _report ok "$p parses" || _report no "$p does not parse"
done

echo "-- agent policy"
AG=guard.yaml
python3 -B "$E" --check --agent "$AG" >/dev/null 2>&1 && _report ok "agent policy parses" || _report no "agent policy does not parse"
acheck() { # acheck <rc> <label> <tool_name>
  local out rc
  out=$(printf '{"tool_name":"%s","tool_input":{}}' "$3" | python3 -B "$E" --agent "$AG" "sales-partner agent guard policy" 2>&1); rc=$?
  if [ "$rc" -eq "$1" ]; then _report ok "$2"; else _report no "$2 (rc=$rc): $out"; fi
}
for t in mcp__claude_ai_Gmail__send_message mcp__claude_ai_Gmail__reply mcp__claude_ai_Gmail__forward \
         mcp__claude_ai_Slack__slack_send_message mcp__claude_ai_Slack__slack_schedule_message \
         mcp__claude_ai_Zernio__posts_publish_now mcp__claude_ai_Zernio__posts_create mcp__claude_ai_Zernio__posts_cross_post \
         mcp__claude_ai_Zernio__posts_bulk_upload_posts mcp__claude_ai_Loops__execute_write \
         mcp__claude_ai_Zernio__comments_reply_to_inbox_post mcp__claude_ai_ClickUp__clickup_send_chat_message \
         mcp__claude_ai_Zernio__call_tool mcp__claude_ai_Zernio__posts_retry mcp__claude_ai_Zernio__posts_retry_all_failed \
         mcp__claude_ai_Google_Calendar__create_event mcp__claude_ai_Google_Calendar__update_event \
         mcp__claude_ai_Google_Calendar__respond_to_event; do
  acheck 2 "denied: $t" "$t"
done
for t in mcp__claude_ai_Attio__list-comment-replies mcp__claude_ai_Attio__list-records \
         mcp__claude_ai_Beehiiv__list_publications mcp__claude_ai_Beehiiv__get_publication \
         mcp__claude_ai_HubSpot__manage_crm_objects mcp__claude_ai_HubSpot__search_crm_objects \
         mcp__claude_ai_Slack__slack_read_channel \
         mcp__claude_ai_Slack__slack_read_thread mcp__claude_ai_ClickUp__clickup_get_chat_message_replies \
         mcp__claude_ai_Zernio__posts_list mcp__claude_ai_Loops__execute mcp__claude_ai_Notion__notion-search \
         mcp__claude_ai_Google_Calendar__list_events mcp__claude_ai_Google_Calendar__get_event \
         mcp__claude_ai_Google_Calendar__search_events mcp__claude_ai_Zernio__search_tools; do
  acheck 0 "read or CRM write passes: $t" "$t"
done

for t in execute_workflow test_workflow create_workflow_from_code update_workflow archive_workflow publish_workflow unpublish_workflow restore_workflow_version; do
  acheck 2 "n8n dispatcher denied: $t" "mcp__claude_ai_N8N_Webspenser_Newsletter__$t"
done
# owner_notify is exempt: its server passes the agent deny only when guard.sh
# grants --exempt (the bound tool covers owner_only_send); its own policy then decides.
python3 -B "$E" --exempt-caps "$AG" | grep -qx owner_notify && _report ok "agent policy exempts owner_notify" || _report no "agent policy does not exempt owner_notify"
RS=mcp__claude_ai_Resend__send-email
out=$(printf '{"tool_name":"%s","tool_input":{}}' "$RS" | python3 -B "$E" --agent "$AG" "agent" 2>&1); rc=$?
[ "$rc" -eq 2 ] && _report ok "resend send denied without the exemption" || _report no "resend send without exemption (rc=$rc): $out"
out=$(printf '{"tool_name":"%s","tool_input":{}}' "$RS" | python3 -B "$E" --agent "$AG" "agent" --exempt resend 2>&1); rc=$?
[ "$rc" -eq 0 ] && _report ok "resend send passes the agent policy with the exemption" || _report no "resend send with exemption (rc=$rc): $out"
out=$(printf '{"tool_name":"%s","tool_input":{}}' mcp__claude_ai_Gmail__send_message | python3 -B "$E" --agent "$AG" "agent" --exempt resend 2>&1); rc=$?
[ "$rc" -eq 2 ] && _report ok "the exemption does not reach Gmail" || _report no "gmail with resend exemption (rc=$rc): $out"
out=$(printf '{"tool_name":"%s","tool_input":{}}' mcp__claude_ai_Gmail__resend_message | python3 -B "$E" --agent "$AG" "agent" --exempt resend 2>&1); rc=$?
[ "$rc" -eq 2 ] && _report ok "the exemption needs resend in the server, not the tool name" || _report no "resend in tool name (rc=$rc): $out"

echo "-- owner_notify (resend)"
NP=capabilities/owner_notify/tools/resend/guard.yaml; R=mcp__claude_ai_Resend__; SM=resend
printf '%s\n' 'recipient_email: owner@acme.com' 'recipient_email: ops@acme.com' 'sender_email: no-reply@notify.acme.com' > "$W/notify.md"
OK='"from":"no-reply@notify.acme.com","subject":"[sales-partner] digest: x","text":"y"'
check 0 "owner send passes"           $NP ${R}send-email "{\"to\":[\"owner@acme.com\"],$OK}" "" "$W/notify.md"
check 0 "both owners pass"            $NP ${R}send-email "{\"to\":[\"owner@acme.com\",\"OPS@acme.com\"],$OK}" "" "$W/notify.md"
check 0 "owner cc passes"             $NP ${R}send-email "{\"to\":[\"owner@acme.com\"],\"cc\":[\"ops@acme.com\"],$OK}" "" "$W/notify.md"
check 0 "html body passes"            $NP ${R}send-email "{\"to\":[\"owner@acme.com\"],$OK,\"html\":\"<p>y</p>\"}" "" "$W/notify.md"
check 2 "prospect send blocked"       $NP ${R}send-email "{\"to\":[\"lead@prospect.com\"],$OK}" "is not a pinned value" "$W/notify.md"
check 2 "owner plus prospect blocked" $NP ${R}send-email "{\"to\":[\"owner@acme.com\",\"lead@prospect.com\"],$OK}" "is not a pinned value" "$W/notify.md"
check 2 "extra cc blocked"            $NP ${R}send-email "{\"to\":[\"owner@acme.com\"],\"cc\":[\"lead@prospect.com\"],$OK}" "is not a pinned value" "$W/notify.md"
check 2 "extra bcc blocked"           $NP ${R}send-email "{\"to\":[\"owner@acme.com\"],\"bcc\":[\"lead@prospect.com\"],$OK}" "is not a pinned value" "$W/notify.md"
check 2 "no recipient blocked"        $NP ${R}send-email "{$OK}" "names no pinned value" "$W/notify.md"
check 2 "other sender blocked"        $NP ${R}send-email '{"to":["owner@acme.com"],"from":"owner@acme.com","subject":"s","text":"y"}' "(sender_email)" "$W/notify.md"
check 2 "display-name sender blocked" $NP ${R}send-email '{"to":["owner@acme.com"],"from":"Acme <no-reply@notify.acme.com>","subject":"s","text":"y"}' "(sender_email)" "$W/notify.md"
check 2 "no bindings blocked"         $NP ${R}send-email "{\"to\":[\"owner@acme.com\"],$OK}" "no recipient_email line"
for a in '"replyTo":["lead@prospect.com"]' '"reply_to":["lead@prospect.com"]' '"headers":{"Bcc":"lead@prospect.com"}' \
         '"scheduledAt":"in 1 hour"' '"attachments":[{"filename":"a.pdf","url":"https://x.test/a"}]' '"topicId":"t1"'; do
  check 2 "refused: ${a%%:*}"         $NP ${R}send-email "{\"to\":[\"owner@acme.com\"],$OK,$a}" "may not use" "$W/notify.md"
done
check 0 "domain read passes"          $NP ${R}list-domains '{}' "" "$W/notify.md"
check 0 "domain get passes"           $NP ${R}get-domain '{"id":"d1"}' "" "$W/notify.md"
for t in send-batch-emails send-broadcast create-broadcast reply-to-inbox-thread-email forward-inbox-thread-email \
         send-inbox-draft send-event create-automation update-email share-email create-api-key create-webhook \
         create-contact create-segment remove-domain get_more_tools; do
  check 2 "blocked: $t"               $NP ${R}$t '{}' "" "$W/notify.md"
done
check 2 "send-email on another server not allowed" $NP mcp__claude_ai_Gmail__send-email "{\"to\":[\"owner@acme.com\"],$OK}" "" "$W/notify.md"
SM=

echo "-- ledger (airtable)"
LG=capabilities/ledger/tools/airtable/guard.yaml; A=mcp__claude_ai_Airtable__; SM=airtable
printf '%s\n' 'base_id: appAAAAAAAAAAAAAA' 'field_at: fldAT000000000000' 'field_run_id: fldRUN00000000000' \
  'field_seq: fldSEQ00000000000' 'field_event: fldEVT00000000000' > "$W/ledger.md"
R='"baseId":"appAAAAAAAAAAAAAA","tableId":"tblE0000000000000"'
check 0 "append an event"     $LG ${A}create_records_for_table "{$R,\"records\":[{\"fields\":{\"fldRUN00000000000\":\"prospect-20261019T1400Z\",\"fldSEQ00000000000\":1,\"fldEVT00000000000\":\"run_started\"}}]}" "" "$W/ledger.md"
check 2 "edit an event"       $LG ${A}update_records_for_table "{$R,\"records\":[{\"id\":\"recA0000000000000\",\"fields\":{\"fldEVT00000000000\":\"error\"}}]}" "Event may not be changed after create" "$W/ledger.md"
check 2 "upsert into Events"  $LG ${A}update_records_for_table "{$R,\"performUpsert\":{\"fieldIdsToMergeOn\":[\"fldRUN00000000000\"]},\"records\":[{\"fields\":{\"fldRUN00000000000\":\"x\"}}]}" "Run ID may not be changed after create" "$W/ledger.md"
check 2 "typecast false"      $LG ${A}create_records_for_table "{$R,\"typecast\":false,\"records\":[{\"fields\":{\"fldEVT00000000000\":\"step\"}}]}" "may not use typecast" "$W/ledger.md"
check 2 "unrecorded field ID" $LG ${A}create_records_for_table "{$R,\"records\":[{\"fields\":{\"fldOTHER000000000\":\"x\"}}]}" "is not a recorded field ID" "$W/ledger.md"
for t in delete_records_for_table create_field update_field create_table create_base create_automation revert_action; do
  check 2 "blocked: $t"       $LG ${A}$t "{$R}" "" "$W/ledger.md"
done
check 0 "read records"        $LG ${A}list_records_for_table "{$R}" "" "$W/ledger.md"
SM=

echo "-- scraping (apify)"
jset() { python3 -c 'import json,sys;d=json.loads(sys.argv[1]);d[sys.argv[2]]=json.loads(sys.argv[3]);print(json.dumps(d))' "$@"; }
jdel() { python3 -c 'import json,sys;d=json.loads(sys.argv[1]);del d[sys.argv[2]];print(json.dumps(d))' "$@"; }
AG2=capabilities/scraping/tools/apify/guard.yaml; P=mcp__claude_ai_Apify__; SM=apify
MAPS=compass--crawler-google-places; CONTACTS=vdrmota--contact-info-scraper
printf '%s\n' 'max_places_per_search: 60' 'max_pages_per_site: 3' 'max_crawl_depth: 1' 'max_pages_per_call: 30' \
  'max_search_terms: 1' 'max_sites_per_call: 10' 'max_dataset_items: 100' \
  'max_reviews: 50' 'max_ads: 5' 'max_jobs: 20' 'max_site_pages: 5' 'max_site_depth: 1' 'max_review_places: 1' \
  'max_ad_queries: 1' 'max_ad_advertisers: 1' 'ads_result_type: advertisers' 'site_crawler_type: cheerio' \
  'site_html_transformer: none' 'max_site_urls: 1' 'max_profile_results: 5' 'max_profile_reads: 10' \
  'max_profile_locations: 1' 'max_web_results: 10' 'max_bbb_results: 5' > "$W/scraping.md"
MAPS_OK='{"maxCrawledPlacesPerSearch":60,"searchStringsArray":["HVAC contractor"],"city":"Alameda","state":"CA","countryCode":"us","language":"en","waitSecs":45}'
CT='"maxRequestsPerStartUrl":3,"maxDepth":1,"maxRequests":30'
U1='{"url":"https://example.com"}'
check 0 "maps in limit"            $AG2 ${P}$MAPS "$MAPS_OK" "" "$W/scraping.md"
check 2 "maps over limit"          $AG2 ${P}$MAPS '{"maxCrawledPlacesPerSearch":5000}' "5000 is not a pinned value (max_places_per_search)" "$W/scraping.md"
check 2 "maps limit omitted"       $AG2 ${P}$MAPS '{"searchStringsArray":["x"]}' "names no pinned value" "$W/scraping.md"
check 2 "maps two search terms"    $AG2 ${P}$MAPS '{"maxCrawledPlacesPerSearch":60,"searchStringsArray":["a","b"]}' "exceeds max_search_terms" "$W/scraping.md"
check 2 "maps no search term"      $AG2 ${P}$MAPS '{"maxCrawledPlacesPerSearch":60,"city":"Alameda"}' "names no searchStringsArray" "$W/scraping.md"
check 2 "maps empty search terms"  $AG2 ${P}$MAPS '{"maxCrawledPlacesPerSearch":60,"searchStringsArray":[]}' "" "$W/scraping.md"
check 2 "maps respelled key alone" $AG2 ${P}$MAPS '{"maxCrawledPlacesPerSearch":60,"SearchStringsArray":["x"]}' "names no searchStringsArray" "$W/scraping.md"
for a in locationQuery startUrls placeIds customGeolocation scrapeContacts maxReviews scrapePlaceDetailPage website maximumLeadsEnrichmentRecords leadsEnrichmentDepartments verifyLeadsEnrichmentEmails maxImages maxQuestions enableCompetitorAnalysis maxCompetitorsToAnalyze includeWebResults scrapeDirectories scrapeOrderOnline scrapeTableReservationProvider scrapeSocialMediaProfiles scrapeImageAuthors scrapeReviewsPersonalData reviewsFilterString reviewsOrigin reviewsSort reviewsStartDate categoryFilterWords placeMinimumStars searchMatching skipClosedPlaces allPlacesNoSearchAction; do
  check 2 "maps may not set $a"    $AG2 ${P}$MAPS "$(jset "$MAPS_OK" "$a" '"x"')" "must send $a = null" "$W/scraping.md"
done
check 2 "maps false add-on"        $AG2 ${P}$MAPS "$(jset "$MAPS_OK" scrapeContacts false)" "must send scrapeContacts = null" "$W/scraping.md"
check 0 "maps null scope key passes" $AG2 ${P}$MAPS "$(jset "$MAPS_OK" startUrls null)" "" "$W/scraping.md"
check 0 "maps unknown harmless input passes" $AG2 ${P}$MAPS "$(jset "$MAPS_OK" someNewVendorOption true)" "" "$W/scraping.md"
for a in pageFunction headers cookies proxyConfiguration webhooks; do
  check 2 "maps shared refusal $a" $AG2 ${P}$MAPS "$(jset "$MAPS_OK" "$a" '"x"')" "may not use $a" "$W/scraping.md"
done
check 0 "contacts in limit"        $AG2 ${P}$CONTACTS "{\"startUrls\":[$U1],$CT,\"sameDomain\":true,\"mergeContacts\":true,\"considerChildFrames\":false,\"waitSecs\":45}" "" "$W/scraping.md"
check 2 "contacts pages raised"    $AG2 ${P}$CONTACTS '{"startUrls":[{"url":"https://example.com"}],"maxRequestsPerStartUrl":50,"maxDepth":1,"maxRequests":30}' "is not a pinned value (max_pages_per_site)" "$W/scraping.md"
check 2 "contacts depth raised"    $AG2 ${P}$CONTACTS '{"startUrls":[{"url":"https://example.com"}],"maxRequestsPerStartUrl":3,"maxDepth":5,"maxRequests":30}' "is not a pinned value (max_crawl_depth)" "$W/scraping.md"
check 2 "contacts depth omitted"   $AG2 ${P}$CONTACTS '{"startUrls":[{"url":"https://example.com"}],"maxRequestsPerStartUrl":3,"maxRequests":30}' "names no pinned value" "$W/scraping.md"
check 2 "contacts calls unbounded" $AG2 ${P}$CONTACTS '{"startUrls":[{"url":"https://example.com"}],"maxRequestsPerStartUrl":3,"maxDepth":1,"maxRequests":9999999}' "is not a pinned value (max_pages_per_call)" "$W/scraping.md"
check 2 "contacts call cap omitted" $AG2 ${P}$CONTACTS '{"startUrls":[{"url":"https://example.com"}],"maxRequestsPerStartUrl":3,"maxDepth":1}' "names no pinned value" "$W/scraping.md"
URLS11=$(python3 -c 'import json;print(json.dumps([{"url":"https://e%d.com"%i} for i in range(11)]))')
check 2 "contacts 11 URLs"         $AG2 ${P}$CONTACTS "{\"startUrls\":$URLS11,$CT}" "exceeds max_sites_per_call" "$W/scraping.md"
check 2 "contacts no startUrls"    $AG2 ${P}$CONTACTS "{$CT}" "names no startUrls" "$W/scraping.md"
check 2 "contacts empty startUrls" $AG2 ${P}$CONTACTS "{\"startUrls\":[],$CT}" "" "$W/scraping.md"
check 2 "contacts proxyConfig"     $AG2 ${P}$CONTACTS "{\"startUrls\":[$U1],$CT,\"proxyConfig\":{\"useApifyProxy\":true,\"apifyProxyGroups\":[\"RESIDENTIAL\"]}}" "may not use" "$W/scraping.md"
for a in useBrowser waitUntil maximumLeadsEnrichmentRecords leadsEnrichmentDepartments verifyLeadsEnrichmentEmails scrapeSocialMediaProfiles; do
  check 2 "contacts may not set $a" $AG2 ${P}$CONTACTS "{\"startUrls\":[$U1],$CT,\"$a\":\"x\"}" "must send $a = null" "$W/scraping.md"
done
check 0 "contacts unknown harmless input passes" $AG2 ${P}$CONTACTS "{\"startUrls\":[$U1],$CT,\"someNewVendorOption\":true}" "" "$W/scraping.md"
check 2 "start URL requestsFromUrl" $AG2 ${P}$CONTACTS "{\"startUrls\":[{\"url\":\"https://example.com\",\"requestsFromUrl\":\"https://x.test/list.txt\"}],$CT}" "may not use" "$W/scraping.md"
check 2 "start URL method"         $AG2 ${P}$CONTACTS "{\"startUrls\":[{\"url\":\"https://example.com\",\"method\":\"POST\"}],$CT}" "may not use" "$W/scraping.md"
check 2 "start URL headers"        $AG2 ${P}$CONTACTS "{\"startUrls\":[{\"url\":\"https://example.com\",\"headers\":{}}],$CT}" "may not use" "$W/scraping.md"
check 2 "start URL payload"        $AG2 ${P}$CONTACTS "{\"startUrls\":[{\"url\":\"https://example.com\",\"payload\":\"x\"}],$CT}" "may not use" "$W/scraping.md"
check 2 "start URL userData"       $AG2 ${P}$CONTACTS "{\"startUrls\":[{\"url\":\"https://example.com\",\"userData\":{}}],$CT}" "may not use" "$W/scraping.md"
check 2 "no bindings blocked"      $AG2 ${P}$MAPS "$MAPS_OK" "no max_places_per_search line"
check 0 "run status read passes"   $AG2 ${P}get-actor-run '{"runId":"r1","waitSecs":45}' "" "$W/scraping.md"
check 2 "run read other arg"       $AG2 ${P}get-actor-run '{"runId":"r1","token":"x"}' "may not use" "$W/scraping.md"
check 0 "dataset read passes"      $AG2 ${P}get-dataset-items '{"datasetId":"d1","fields":"title,phone","limit":100,"offset":0,"clean":true}' "" "$W/scraping.md"
check 2 "dataset limit 1000"       $AG2 ${P}get-dataset-items '{"datasetId":"d1","limit":1000}' "exceeds max_dataset_items" "$W/scraping.md"
check 2 "dataset other arg"        $AG2 ${P}get-dataset-items '{"datasetId":"d1","flatten":"x"}' "may not use" "$W/scraping.md"
for t in call-actor search-actors add-actor fetch-actor-details abort-actor-run get-key-value-store-record; do
  check 2 "blocked: $t"            $AG2 ${P}$t '{}' "" "$W/scraping.md"
done
check 2 "another actor"            $AG2 ${P}apify-slash-instagram-scraper '{}' "" "$W/scraping.md"

# 8.1 evidence actors, under the server name the restricted connector shows.
P2=mcp__claude_ai_Apify_Actors__
REV=web_wanderer--google-reviews-scraper; GADS=scrapesage--google-ads-transparency-scraper
FB=apify--facebook-ads-scraper; JOBS=valig--indeed-jobs-scraper; SITE=apify--website-content-crawler
pins() { # pins <label> <tool> <ok json> <key>:<bound>:<raised json>...: each pin raised, then omitted
  local label=$1 tool=$2 ok=$3 spec key bound; shift 3
  for spec in "$@"; do
    key=${spec%%:*}; bound=${spec#*:}; bound=${bound%%:*}
    check 2 "$label $key raised"  $AG2 ${P2}$tool "$(jset "$ok" "$key" "${spec#*:*:}")" "is not a pinned value ($bound)" "$W/scraping.md"
    check 2 "$label $key omitted" $AG2 ${P2}$tool "$(jdel "$ok" "$key")" "names no pinned value at $key" "$W/scraping.md"
  done
}
lists() { # lists <label> <tool> <ok json> <key>:<bound>:<over-bound list json>...: over, empty, omitted
  local label=$1 tool=$2 ok=$3 spec key bound; shift 3
  for spec in "$@"; do
    key=${spec%%:*}; bound=${spec#*:}; bound=${bound%%:*}
    check 2 "$label $key over $bound" $AG2 ${P2}$tool "$(jset "$ok" "$key" "${spec#*:*:}")" "exceeds $bound at $key" "$W/scraping.md"
    check 2 "$label $key empty"       $AG2 ${P2}$tool "$(jset "$ok" "$key" '[]')" "names no $key" "$W/scraping.md"
    check 2 "$label $key omitted"     $AG2 ${P2}$tool "$(jdel "$ok" "$key")" "names no $key" "$W/scraping.md"
  done
}
refused() { # refused <label> <tool> <ok json> <key>...: each key blocked, even set to false
  local label=$1 tool=$2 ok=$3 key; shift 3
  for key in "$@"; do
    check 2 "$label may not use $key (false)" $AG2 ${P2}$tool "$(jset "$ok" "$key" false)" "may not use $key" "$W/scraping.md"
  done
}
nulled() { # nulled <label> <tool> <ok json> <key>...: each per-tool scope key blocked, even set to false
  local label=$1 tool=$2 ok=$3 key; shift 3
  for key in "$@"; do
    check 2 "$label may not set $key (false)" $AG2 ${P2}$tool "$(jset "$ok" "$key" false)" "must send $key = null" "$W/scraping.md"
  done
}
harmless() { # harmless <label> <tool> <ok json>: an unknown vendor option passes (open profile)
  check 0 "$1 unknown harmless input passes" $AG2 ${P2}$2 "$(jset "$3" someNewVendorOption true)" "" "$W/scraping.md"
}
start_extras() { # start_extras <label> <tool> <ok json> <allowed url>: nothing but url on a start URL
  local a
  for a in requestsFromUrl method headers payload userData; do
    check 2 "$1 start URL $a" $AG2 ${P2}$2 "$(jset "$3" startUrls "[{\"url\":\"$4\",\"$a\":\"x\"}]")" "may not use startUrls[].$a" "$W/scraping.md"
  done
  check 2 "$1 start URL as a bare string" $AG2 ${P2}$2 "$(jset "$3" startUrls "[\"$4\"]")" "startUrls[].requestsFromUrl: unexpected shape" "$W/scraping.md"
}
start_url() { # start_url <rc> <label> <tool> <ok json> <url> [text]: the ok call with one start URL
  check "$1" "$2" $AG2 ${P2}$3 "$(jset "$4" startUrls "[{\"url\":\"$5\"}]")" "${6:-}" "$W/scraping.md"
}

check 0 "maps on the Apify_Actors server passes" $AG2 ${P2}$MAPS "$MAPS_OK" "" "$W/scraping.md"
check 2 "Apify_Actors call-actor denied" $AG2 ${P2}call-actor '{}' "is denied" "$W/scraping.md"
check 2 "reviews tool on another server not allowed" $AG2 mcp__claude_ai_Gmail__$REV '{}' "is not in the allow list" "$W/scraping.md"

REV_OK='{"place_ids":["ChIJkyhXi8iHj4ARLP5o2YRo-iY"],"limit":50,"order":"newest","include_personal":true,"lang":"en","waitSecs":45}'
check 0 "reviews in limit with include_personal true" $AG2 ${P2}$REV "$REV_OK" "" "$W/scraping.md"
check 0 "reviews tool name matches in any case"    $AG2 ${P2}web_wanderer--Google-Reviews-Scraper "$REV_OK" "" "$W/scraping.md"
check 0 "reviews with date, keyword and source"    $AG2 ${P2}$REV '{"place_ids":["ChIJkyhXi8iHj4ARLP5o2YRo-iY"],"limit":50,"order":"newest","anyDate":"2025-10-18","searchKeyword":"voicemail","source":"google","include_personal":true,"lang":"en","waitSecs":45}' "" "$W/scraping.md"
check 0 "reviews on the Apify_Connector server"    $AG2 mcp__claude_ai_Apify_Connector__$REV "$REV_OK" "" "$W/scraping.md"
check 2 "old Compass reviews tool not allowed"     $AG2 ${P2}compass--Google-Maps-Reviews-Scraper '{"placeIds":["ChIJkyhXi8iHj4ARLP5o2YRo-iY"],"maxReviews":50,"personalData":false}' "is not in the allow list" "$W/scraping.md"
pins    reviews $REV "$REV_OK" 'limit:max_reviews:200'
lists   reviews $REV "$REV_OK" 'place_ids:max_review_places:["ChIJaaaaaaaaaaaaaaaaaaaaaaa","ChIJbbbbbbbbbbbbbbbbbbbbbbb"]'
check 0 "reviews respelled key beside the real one passes" $AG2 ${P2}$REV "$(jset "$REV_OK" placeIds '["ChIJx"]')" "" "$W/scraping.md"
harmless reviews $REV "$REV_OK"
nulled reviews $REV "$REV_OK" place_urls search search_location search_limit search_coordination sort_dataset sort_keys
check 2 "reviews place_urls list"  $AG2 ${P2}$REV "$(jset "$REV_OK" place_urls '["https://maps.google.com/?cid=1"]')" "must send place_urls = null" "$W/scraping.md"
check 2 "reviews keyword search"   $AG2 ${P2}$REV "$(jset "$REV_OK" search '["plumbers"]')" "must send search = null" "$W/scraping.md"
check 2 "reviews without bindings" $AG2 ${P2}$REV "$REV_OK" "no max_reviews line"
check 2 "reviews include_personal false"    $AG2 ${P2}$REV "$(jset "$REV_OK" include_personal false)" "must send include_personal = true (got false)" "$W/scraping.md"
check 2 "reviews include_personal omitted"  $AG2 ${P2}$REV "$(jdel "$REV_OK" include_personal)" "names no include_personal" "$W/scraping.md"
check 2 "reviews include_personal as a string" $AG2 ${P2}$REV "$(jset "$REV_OK" include_personal '"true"')" "must send include_personal = true" "$W/scraping.md"
check 2 "reviews include_personal null"     $AG2 ${P2}$REV "$(jset "$REV_OK" include_personal null)" "must send include_personal = true (got null)" "$W/scraping.md"

GADS_OK='{"queries":["bigbrothersplumbinginc.com"],"resultType":"advertisers","maxAdvertisersPerQuery":1,"maxAdsPerSearch":5,"region":"US","waitSecs":45}'
check 0 "google ads in limit"      $AG2 ${P2}$GADS "$GADS_OK" "" "$W/scraping.md"
pins    "google ads" $GADS "$GADS_OK" 'maxAdsPerSearch:max_ads:100' 'maxAdvertisersPerQuery:max_ad_advertisers:5' 'resultType:ads_result_type:"ads"'
lists   "google ads" $GADS "$GADS_OK" 'queries:max_ad_queries:["a.com","b.com"]'
check 0 "google ads respelled key passes" $AG2 ${P2}$GADS "$(jset "$GADS_OK" max_ads_per_search 5)" "" "$W/scraping.md"
harmless "google ads" $GADS "$GADS_OK"
refused "google ads" $GADS "$GADS_OK" proxyConfiguration
nulled "google ads" $GADS "$GADS_OK" includeDetails onlyNewAds monitorStoreName includeRawData startUrls urlsFromFile domains advertiserIds
check 2 "google ads proxyConfiguration object" $AG2 ${P2}$GADS "$(jset "$GADS_OK" proxyConfiguration '{"useApifyProxy":true,"apifyProxyGroups":["DATACENTER"]}')" "may not use proxyConfiguration" "$W/scraping.md"
check 2 "google ads domains list"  $AG2 ${P2}$GADS "$(jset "$GADS_OK" domains '["bigbrothersplumbinginc.com"]')" "must send domains = null" "$W/scraping.md"
check 2 "google ads includeDetails true" $AG2 ${P2}$GADS "$(jset "$GADS_OK" includeDetails true)" "must send includeDetails = null" "$W/scraping.md"
grep -v '^ads_result_type:' "$W/scraping.md" > "$W/scraping-notext.md"
check 2 "google ads without the text pin" $AG2 ${P2}$GADS "$GADS_OK" "no ads_result_type line" "$W/scraping-notext.md"

FB_OK='{"startUrls":[{"url":"https://www.facebook.com/bigbrothersplumbinginc"}],"onlyTotal":true,"resultsLimit":5,"activeStatus":"active","onlyAdsNewerThan":"2026-01-01","waitSecs":45}'
check 0 "facebook in limit"        $AG2 ${P2}$FB "$FB_OK" "" "$W/scraping.md"
pins    facebook $FB "$FB_OK" 'resultsLimit:max_ads:100'
check 2 "facebook resultsLimit empty (unlimited)" $AG2 ${P2}$FB "$(jset "$FB_OK" resultsLimit '""')" "is not a pinned value (max_ads)" "$W/scraping.md"
check 2 "facebook resultsLimit null" $AG2 ${P2}$FB "$(jset "$FB_OK" resultsLimit null)" "names no pinned value at resultsLimit" "$W/scraping.md"
lists   facebook $FB "$FB_OK" 'startUrls:max_ad_queries:[{"url":"https://www.facebook.com/a"},{"url":"https://www.facebook.com/b"}]'
check 0 "facebook respelled key passes" $AG2 ${P2}$FB "$(jset "$FB_OK" ResultsLimit 5)" "" "$W/scraping.md"
harmless facebook $FB "$FB_OK"
refused facebook $FB "$FB_OK" proxyConfiguration
nulled facebook $FB "$FB_OK" isDetailsPerAd includeAboutPage enrichWithEcommerceData sorting onlyAdsOlderThan
check 2 "facebook enrichWithEcommerceData true" $AG2 ${P2}$FB "$(jset "$FB_OK" enrichWithEcommerceData true)" "must send enrichWithEcommerceData = null" "$W/scraping.md"
start_extras facebook $FB "$FB_OK" https://www.facebook.com/bigbrothersplumbinginc
check 2 "facebook onlyTotal omitted" $AG2 ${P2}$FB "$(jdel "$FB_OK" onlyTotal)" "names no onlyTotal" "$W/scraping.md"
check 2 "facebook onlyTotal false"   $AG2 ${P2}$FB "$(jset "$FB_OK" onlyTotal false)" "must send onlyTotal = true (got false)" "$W/scraping.md"
start_url 0 "facebook page on facebook.com" $FB "$FB_OK" https://facebook.com/bigbrothersplumbinginc
start_url 2 "facebook keyword Ad Library URL" $FB "$FB_OK" \
  'https://www.facebook.com/ads/library/?active_status=active&ad_type=all&country=US&q=big%20brothers%20plumbing&search_type=keyword_unordered' "a query is not allowed"
start_url 2 "facebook profile id page"  $FB "$FB_OK" 'https://www.facebook.com/profile.php?id=100064' "a query is not allowed"
start_url 2 "facebook fragment"         $FB "$FB_OK" 'https://www.facebook.com/bigbrothersplumbinginc#about' "a fragment is not allowed"
start_url 2 "facebook m. host"          $FB "$FB_OK" https://m.facebook.com/x "host m.facebook.com is not in the hosts list"
start_url 2 "facebook web. host"        $FB "$FB_OK" https://web.facebook.com/x "is not in the hosts list"
start_url 2 "facebook other host"       $FB "$FB_OK" https://evil.com/x "host evil.com is not in the hosts list"
start_url 2 "facebook lookalike host"   $FB "$FB_OK" https://www.facebook.com.evil.com/x "is not in the hosts list"
start_url 2 "facebook over http"        $FB "$FB_OK" http://www.facebook.com/x "scheme http is not allowed"
start_url 2 "facebook user info"        $FB "$FB_OK" https://www.facebook.com@evil.com/x "user info (@) is not allowed"
check 2 "facebook start URL without url" $AG2 ${P2}$FB "$(jset "$FB_OK" startUrls '[{}]')" "names no startUrls[].url" "$W/scraping.md"
check 2 "facebook start URL not a string" $AG2 ${P2}$FB "$(jset "$FB_OK" startUrls '[{"url":5}]')" "startUrls[].url must be a URL string" "$W/scraping.md"

JOBS_OK='{"title":"Big Brothers Plumbing","location":"Alameda, CA","country":"us","limit":20,"datePosted":"30","waitSecs":45}'
check 0 "jobs in limit"            $AG2 ${P2}$JOBS "$JOBS_OK" "" "$W/scraping.md"
pins    jobs $JOBS "$JOBS_OK" 'limit:max_jobs:100'
check 0 "jobs respelled key passes" $AG2 ${P2}$JOBS "$(jset "$JOBS_OK" Title '"x"')" "" "$W/scraping.md"
harmless jobs $JOBS "$JOBS_OK"
refused jobs $JOBS "$JOBS_OK" proxyConfiguration
nulled jobs $JOBS "$JOBS_OK" maxItems startUrls

SITE_OK='{"startUrls":[{"url":"https://bigbrothersplumbinginc.com/"}],"crawlerType":"cheerio","maxCrawlPages":5,"maxResults":5,"maxCrawlDepth":1,"htmlTransformer":"none","removeElementsCssSelector":"script, style, noscript, svg","saveMarkdown":true,"waitSecs":45}'
check 0 "site reader in limit"     $AG2 ${P2}$SITE "$SITE_OK" "" "$W/scraping.md"
pins    "site reader" $SITE "$SITE_OK" 'crawlerType:site_crawler_type:"playwright:firefox"' 'htmlTransformer:site_html_transformer:"readableText"' \
  'maxCrawlPages:max_site_pages:9999999' 'maxResults:max_site_pages:9999999' 'maxCrawlDepth:max_site_depth:20'
lists   "site reader" $SITE "$SITE_OK" 'startUrls:max_site_urls:[{"url":"https://example.com"},{"url":"https://www.example.com"}]'
check 0 "site reader respelled key passes" $AG2 ${P2}$SITE "$(jset "$SITE_OK" maxCrawlpages 5)" "" "$W/scraping.md"
harmless "site reader" $SITE "$SITE_OK"
refused "site reader" $SITE "$SITE_OK" customHttpHeaders pageFunction initialCookies proxyConfiguration preNavigationHooks postNavigationHooks
nulled "site reader" $SITE "$SITE_OK" summarize saveScreenshots saveContentTypes \
  saveFiles saveHtmlAsFile includeUrlGlobs useSitemaps useLlmsTxt clickElementsCssSelector waitForSelector maxConcurrency
check 2 "site reader customHttpHeaders object" $AG2 ${P2}$SITE "$(jset "$SITE_OK" customHttpHeaders '{"Cookie":"session=x"}')" "may not use customHttpHeaders" "$W/scraping.md"
check 2 "site reader summarize true"    $AG2 ${P2}$SITE "$(jset "$SITE_OK" summarize true)" "must send summarize = null" "$W/scraping.md"
check 2 "site reader useSitemaps true"  $AG2 ${P2}$SITE "$(jset "$SITE_OK" useSitemaps true)" "must send useSitemaps = null" "$W/scraping.md"
check 2 "site reader includeUrlGlobs list" $AG2 ${P2}$SITE "$(jset "$SITE_OK" includeUrlGlobs '[{"glob":"https://example.com/**"}]')" "must send includeUrlGlobs = null" "$W/scraping.md"
check 2 "site reader proxyConfiguration object" $AG2 ${P2}$SITE "$(jset "$SITE_OK" proxyConfiguration '{"useApifyProxy":true}')" "may not use proxyConfiguration" "$W/scraping.md"
check 2 "site reader maxConcurrency 200" $AG2 ${P2}$SITE "$(jset "$SITE_OK" maxConcurrency 200)" "must send maxConcurrency = null" "$W/scraping.md"
start_extras "site reader" $SITE "$SITE_OK" https://bigbrothersplumbinginc.com
start_url 0 "site reader root without a slash" $SITE "$SITE_OK" https://bigbrothersplumbinginc.com
start_url 0 "site reader root with the default port" $SITE "$SITE_OK" https://bigbrothersplumbinginc.com:443/
start_url 2 "site reader page path"   $SITE "$SITE_OK" https://bigbrothersplumbinginc.com/contact-us "only the site root is allowed"
start_url 2 "site reader query"       $SITE "$SITE_OK" 'https://bigbrothersplumbinginc.com/?ref=x' "a query is not allowed"
start_url 2 "site reader over http"   $SITE "$SITE_OK" http://bigbrothersplumbinginc.com "scheme http is not allowed"
start_url 2 "site reader IP address"  $SITE "$SITE_OK" https://1.2.3.4 "the host is an IP address"
start_url 2 "site reader local host"  $SITE "$SITE_OK" https://printer.local "is local"
start_url 2 "site reader other port"  $SITE "$SITE_OK" https://bigbrothersplumbinginc.com:8443/ "port 8443 is not the default for https"
start_url 2 "site reader single label" $SITE "$SITE_OK" https://intranet "the host needs at least two labels"
check 2 "site reader saveMarkdown omitted" $AG2 ${P2}$SITE "$(jdel "$SITE_OK" saveMarkdown)" "names no saveMarkdown" "$W/scraping.md"
check 2 "site reader saveMarkdown false"   $AG2 ${P2}$SITE "$(jset "$SITE_OK" saveMarkdown false)" "must send saveMarkdown = true (got false)" "$W/scraping.md"
check 2 "site reader removeElementsCssSelector omitted" $AG2 ${P2}$SITE "$(jdel "$SITE_OK" removeElementsCssSelector)" "names no removeElementsCssSelector" "$W/scraping.md"
check 2 "site reader removeElementsCssSelector changed" $AG2 ${P2}$SITE "$(jset "$SITE_OK" removeElementsCssSelector '"script"')" "must send removeElementsCssSelector = \"script, style, noscript, svg\"" "$W/scraping.md"
check 2 "site reader removeElementsCssSelector empty" $AG2 ${P2}$SITE "$(jset "$SITE_OK" removeElementsCssSelector '""')" "must send removeElementsCssSelector" "$W/scraping.md"

# The contact scraper on the Apify_Actors server: site roots only.
CT_OK="{\"startUrls\":[{\"url\":\"https://bigbrothersplumbinginc.com\"}],$CT,\"sameDomain\":true,\"mergeContacts\":true,\"waitSecs\":45}"
check 0 "contacts root on the Apify_Actors server" $AG2 ${P2}$CONTACTS "$CT_OK" "" "$W/scraping.md"
start_url 0 "contacts root with a slash" $CONTACTS "$CT_OK" https://bigbrothersplumbinginc.com/
start_url 2 "contacts page path"  $CONTACTS "$CT_OK" https://bigbrothersplumbinginc.com/contact-us "only the site root is allowed"
start_url 2 "contacts query"      $CONTACTS "$CT_OK" 'https://bigbrothersplumbinginc.com?x=1' "a query is not allowed"
start_url 2 "contacts over http"  $CONTACTS "$CT_OK" http://bigbrothersplumbinginc.com "scheme http is not allowed"
start_url 2 "contacts IP address" $CONTACTS "$CT_OK" https://10.0.0.1 "the host is an IP address"
check 2 "contacts one bad URL among roots" $AG2 ${P2}$CONTACTS "$(jset "$CT_OK" startUrls '[{"url":"https://a.com"},{"url":"https://b.com/x"}]')" "only the site root is allowed" "$W/scraping.md"
check 2 "contacts start URL requestsFromUrl" $AG2 ${P2}$CONTACTS "$(jset "$CT_OK" startUrls '[{"url":"https://a.com","requestsFromUrl":"https://a.com/list.txt"}]')" "may not use startUrls[].requestsFromUrl" "$W/scraping.md"
check 2 "contacts start URL without url" $AG2 ${P2}$CONTACTS "$(jset "$CT_OK" startUrls '[{"url":"https://a.com"},{}]')" "names no startUrls[].url" "$W/scraping.md"

# 8.3 social profiles: find_profiles (LinkedIn search by name) and
# read_profile (Instagram and TikTok readers, which take handles).
LI=harvestapi--linkedin-profile-search-by-name; IG=apify--instagram-profile-scraper; TT=clockworks--tiktok-profile-scraper
LI_OK='{"firstName":"Alex","lastName":"Example","locations":["Springfield"],"maxItems":5,"maxPages":1,"profileScraperMode":"Full + email search","strictSearch":true,"waitSecs":45}'
check 0 "linkedin search in limit"        $AG2 ${P2}$LI "$LI_OK" "" "$W/scraping.md"
check 0 "linkedin search without a location" $AG2 ${P2}$LI "$(jdel "$LI_OK" locations)" "" "$W/scraping.md"
pins    "linkedin search" $LI "$LI_OK" 'maxItems:max_profile_results:1000'
check 2 "linkedin search maxItems null"   $AG2 ${P2}$LI "$(jset "$LI_OK" maxItems null)" "names no pinned value at maxItems" "$W/scraping.md"
check 2 "linkedin search two locations"   $AG2 ${P2}$LI "$(jset "$LI_OK" locations '["Springfield","California"]')" "exceeds max_profile_locations at locations" "$W/scraping.md"
check 0 "linkedin search respelled cap beside the real one passes" $AG2 ${P2}$LI "$(jset "$LI_OK" MaxItems 5000)" "" "$W/scraping.md"
harmless "linkedin search" $LI "$LI_OK"
refused "linkedin search" $LI "$LI_OK" cookies cookie sessionCookie li_at proxyConfiguration proxy headers customHttpHeaders
nulled "linkedin search" $LI "$LI_OK" currentCompanies pastCompanies schools currentJobTitles industryIds profileUrls searchQuery
check 2 "linkedin search company filter list" $AG2 ${P2}$LI "$(jset "$LI_OK" currentCompanies '["https://www.linkedin.com/company/example"]')" "must send currentCompanies = null" "$W/scraping.md"
check 2 "linkedin search mode omitted"    $AG2 ${P2}$LI "$(jdel "$LI_OK" profileScraperMode)" "names no profileScraperMode" "$W/scraping.md"
check 2 "linkedin search Short mode"      $AG2 ${P2}$LI "$(jset "$LI_OK" profileScraperMode '"Short"')" "must send profileScraperMode = \"Full + email search\"" "$W/scraping.md"
check 2 "linkedin search Full mode without email search" $AG2 ${P2}$LI "$(jset "$LI_OK" profileScraperMode '"Full"')" "must send profileScraperMode = \"Full + email search\"" "$W/scraping.md"
check 2 "linkedin search strictSearch omitted" $AG2 ${P2}$LI "$(jdel "$LI_OK" strictSearch)" "names no strictSearch" "$W/scraping.md"
check 2 "linkedin search strictSearch false"   $AG2 ${P2}$LI "$(jset "$LI_OK" strictSearch false)" "must send strictSearch = true (got false)" "$W/scraping.md"
check 2 "linkedin search strictSearch as a string" $AG2 ${P2}$LI "$(jset "$LI_OK" strictSearch '"true"')" "must send strictSearch = true" "$W/scraping.md"
check 2 "linkedin search maxPages omitted" $AG2 ${P2}$LI "$(jdel "$LI_OK" maxPages)" "names no maxPages" "$W/scraping.md"
check 2 "linkedin search maxPages raised"  $AG2 ${P2}$LI "$(jset "$LI_OK" maxPages 10)" "must send maxPages = 1 (got 10)" "$W/scraping.md"
check 2 "linkedin search without bindings" $AG2 ${P2}$LI "$LI_OK" "no max_profile_results line"

IG_OK='{"usernames":["example.handle"],"waitSecs":45}'
check 0 "instagram read in limit"         $AG2 ${P2}$IG "$IG_OK" "" "$W/scraping.md"
IG11=$(python3 -c 'import json;print(json.dumps(["example%d"%i for i in range(11)]))')
lists   "instagram read" $IG "$IG_OK" "usernames:max_profile_reads:$IG11"
check 0 "instagram read respelled key passes" $AG2 ${P2}$IG "$(jset "$IG_OK" userNames '["example"]')" "" "$W/scraping.md"
harmless "instagram read" $IG "$IG_OK"
refused "instagram read" $IG "$IG_OK" cookies sessionCookie proxyConfiguration proxy headers customHttpHeaders
nulled "instagram read" $IG "$IG_OK" includeAboutSection directUrls resultsLimit resultsType searchType
check 2 "instagram read includeAboutSection true" $AG2 ${P2}$IG "$(jset "$IG_OK" includeAboutSection true)" "must send includeAboutSection = null" "$W/scraping.md"
check 2 "instagram read without bindings" $AG2 ${P2}$IG "$IG_OK" "no max_profile_reads line"

TT_OK='{"profiles":["example.handle"],"resultsPerPage":1,"waitSecs":45}'
check 0 "tiktok read in limit"            $AG2 ${P2}$TT "$TT_OK" "" "$W/scraping.md"
TT11=$(python3 -c 'import json;print(json.dumps(["example%d"%i for i in range(11)]))')
lists   "tiktok read" $TT "$TT_OK" "profiles:max_profile_reads:$TT11"
check 0 "tiktok read respelled key passes" $AG2 ${P2}$TT "$(jset "$TT_OK" Profiles '["example"]')" "" "$W/scraping.md"
harmless "tiktok read" $TT "$TT_OK"
refused "tiktok read" $TT "$TT_OK" cookies proxyConfiguration proxyCountryCode headers
nulled "tiktok read" $TT "$TT_OK" commentsPerPost topLevelCommentsPerPost maxRepliesPerComment maxFollowersPerProfile \
  maxFollowingPerProfile shouldDownloadVideos shouldDownloadCovers shouldDownloadSlideshowImages shouldDownloadAvatars \
  downloadSubtitlesOptions oldestPostDateUnified newestPostDate leastDiggs mostDiggs profileSorting excludePinnedPosts \
  profileScrapeSections videoKvStoreIdOrName
check 2 "tiktok read video download true" $AG2 ${P2}$TT "$(jset "$TT_OK" shouldDownloadVideos true)" "must send shouldDownloadVideos = null" "$W/scraping.md"
check 2 "tiktok read resultsPerPage omitted (default 100)" $AG2 ${P2}$TT "$(jdel "$TT_OK" resultsPerPage)" "names no resultsPerPage" "$W/scraping.md"
check 2 "tiktok read resultsPerPage 100"  $AG2 ${P2}$TT "$(jset "$TT_OK" resultsPerPage 100)" "must send resultsPerPage = 1 (got 100)" "$W/scraping.md"
check 2 "tiktok read resultsPerPage as a string" $AG2 ${P2}$TT "$(jset "$TT_OK" resultsPerPage '"1"')" "must send resultsPerPage = 1" "$W/scraping.md"
check 2 "tiktok read without bindings"    $AG2 ${P2}$TT "$TT_OK" "no max_profile_reads line"

# Phase B. Nested set and delete for the HTTP-shaped web tools (query.url, query.maxResults).
jpset() { python3 -c 'import json,sys;d=json.loads(sys.argv[1]);*h,t=sys.argv[2].split(".");n=d
for k in h: n=n.setdefault(k,{})
n[t]=json.loads(sys.argv[3]);print(json.dumps(d))' "$@"; }
jpdel() { python3 -c 'import json,sys;d=json.loads(sys.argv[1]);*h,t=sys.argv[2].split(".");n=d
for k in h: n=n[k]
del n[t];print(json.dumps(d))' "$@"; }
WS=apify--web-search; WF=apify--web-fetch
WS_OK='{"method":"GET","path":"/","query":{"query":"Franklin Barbecue Austin TX","maxResults":10,"countryCode":"US"}}'
WF_OK='{"method":"GET","path":"/","query":{"url":"https://franklinbbq.com/about","formats":["markdown"]}}'
check 0 "web search in limit"              $AG2 ${P2}$WS "$WS_OK" "" "$W/scraping.md"
check 0 "web fetch a site page"            $AG2 ${P2}$WF "$WF_OK" "" "$W/scraping.md"
harmless "web search" $WS "$WS_OK"
harmless "web fetch" $WF "$WF_OK"
check 0 "web search duckduckgo backup"     $AG2 ${P2}$WS "$(jpset "$WS_OK" query.provider '"duckduckgo"')" "" "$W/scraping.md"
check 0 "web search maxResults as a string" $AG2 ${P2}$WS "$(jpset "$WS_OK" query.maxResults '"5"')" "" "$W/scraping.md"
check 2 "web search maxResults over"       $AG2 ${P2}$WS "$(jpset "$WS_OK" query.maxResults 11)" "max_web_results" "$W/scraping.md"
check 2 "web search maxResults omitted"    $AG2 ${P2}$WS "$(jpdel "$WS_OK" query.maxResults)" "names no query.maxResults" "$W/scraping.md"
check 2 "web search without bindings"      $AG2 ${P2}$WS "$WS_OK" "no max_web_results line"
for T in WS WF; do
  eval "tool=\$$T; ok=\$${T}_OK"
  check 2 "$T as POST"            $AG2 ${P2}$tool "$(jset "$ok" method '"POST"')" 'must send method = "GET"' "$W/scraping.md"
  check 2 "$T method omitted"     $AG2 ${P2}$tool "$(jdel "$ok" method)" "names no method" "$W/scraping.md"
  check 2 "$T other path"         $AG2 ${P2}$tool "$(jset "$ok" path '"/x"')" 'must send path = "/"' "$W/scraping.md"
  check 2 "$T path omitted"       $AG2 ${P2}$tool "$(jdel "$ok" path)" "names no path" "$W/scraping.md"
  check 2 "$T body object"        $AG2 ${P2}$tool "$(jset "$ok" body '{"url":"https://x.com/"}')" "must send body = null" "$W/scraping.md"
  check 2 "$T query headers"      $AG2 ${P2}$tool "$(jpset "$ok" query.headers '"{\"X\":\"1\"}"')" "may not use query.headers" "$W/scraping.md"
done
check 2 "web fetch with a query"           $AG2 ${P2}$WF "$(jpset "$WF_OK" query.url '"https://franklinbbq.com/about?a=1"')" "" "$W/scraping.md"
check 2 "web fetch with a fragment"        $AG2 ${P2}$WF "$(jpset "$WF_OK" query.url '"https://franklinbbq.com/about#x"')" "" "$W/scraping.md"
check 2 "web fetch over http"              $AG2 ${P2}$WF "$(jpset "$WF_OK" query.url '"http://franklinbbq.com/about"')" "" "$W/scraping.md"
check 2 "web fetch an IP address"          $AG2 ${P2}$WF "$(jpset "$WF_OK" query.url '"https://127.0.0.1/"')" "" "$W/scraping.md"
check 2 "web fetch with user info"         $AG2 ${P2}$WF "$(jpset "$WF_OK" query.url '"https://user@franklinbbq.com/"')" "" "$W/scraping.md"
check 2 "web fetch url omitted"            $AG2 ${P2}$WF "$(jpdel "$WF_OK" query.url)" "names no query.url" "$W/scraping.md"
check 2 "web fetch respelled url alone"    $AG2 ${P2}$WF '{"method":"GET","path":"/","query":{"URL":"https://x.com/?a=1"}}' "" "$W/scraping.md"
check 0 "web fetch a search-result page"   $AG2 ${P2}$WF "$(jpset "$WF_OK" query.url '"https://www.femalefoodie.com/restaurant-reviews/franklin-bbq/"')" "" "$W/scraping.md"

BBB=scrapesage--bbb-scraper; YP=delicious_zebu--yellowpages-usa-business-lead-scraper
BBB_OK='{"searchTerms":["Franklin Barbecue"],"locations":["Austin, TX"],"maxResults":5,"includeDetails":true,"waitSecs":45}'
YP_OK='{"searchKeyword":["Franklin Barbecue"],"location":"Austin, TX","maxPages":1,"waitSecs":45}'
check 0 "bbb in limit"                     $AG2 ${P2}$BBB "$BBB_OK" "" "$W/scraping.md"
harmless bbb $BBB "$BBB_OK"
nulled bbb $BBB "$BBB_OK" includeReviews maxReviewsPerBusiness enrichContacts monitorMode monitorKey maxResultsPerSearch \
  maxConcurrency startUrls
check 2 "bbb urlsFromFile"                 $AG2 ${P2}$BBB "$(jset "$BBB_OK" urlsFromFile '"https://x.com/list.txt"')" "may not use urlsFromFile" "$W/scraping.md"
check 2 "bbb maxResults over"              $AG2 ${P2}$BBB "$(jset "$BBB_OK" maxResults 6)" "is not a pinned value (max_bbb_results)" "$W/scraping.md"
check 2 "bbb maxResults 0 (no limit)"      $AG2 ${P2}$BBB "$(jset "$BBB_OK" maxResults 0)" "is not a pinned value (max_bbb_results)" "$W/scraping.md"
check 2 "bbb maxResults omitted"           $AG2 ${P2}$BBB "$(jdel "$BBB_OK" maxResults)" "names no pinned value" "$W/scraping.md"
check 2 "bbb details off"                  $AG2 ${P2}$BBB "$(jset "$BBB_OK" includeDetails false)" "must send includeDetails = true" "$W/scraping.md"
check 2 "bbb details omitted"              $AG2 ${P2}$BBB "$(jdel "$BBB_OK" includeDetails)" "names no includeDetails" "$W/scraping.md"
lists bbb $BBB "$BBB_OK" 'searchTerms:max_search_terms:["a","b"]' 'locations:max_search_terms:["Austin, TX","Dallas, TX"]'
check 2 "bbb proxy"                        $AG2 ${P2}$BBB "$(jset "$BBB_OK" proxyConfiguration '{"useApifyProxy":true}')" "may not use proxyConfiguration" "$W/scraping.md"
check 2 "bbb without bindings"             $AG2 ${P2}$BBB "$BBB_OK" "no max_bbb_results line"
check 0 "yellowpages in limit"             $AG2 ${P2}$YP "$YP_OK" "" "$W/scraping.md"
harmless yellowpages $YP "$YP_OK"
nulled yellowpages $YP "$YP_OK" urls
check 2 "yellowpages two pages"            $AG2 ${P2}$YP "$(jset "$YP_OK" maxPages 2)" "must send maxPages = 1" "$W/scraping.md"
check 2 "yellowpages pages omitted"        $AG2 ${P2}$YP "$(jdel "$YP_OK" maxPages)" "names no maxPages" "$W/scraping.md"
lists yellowpages $YP "$YP_OK" 'searchKeyword:max_search_terms:["a","b"]'
SM=

echo "-- Attio"
AT=capabilities/crm/tools/attio/guard.yaml; P=mcp__claude_ai_Attio__
L='"list":"sales_partner_pipeline","parent_object":"companies","parent_record_id":"00000000-0000-0000-0000-000000000001"'
X='"list":"sales_partner_pipeline","entry_id":"00000000-0000-0000-0000-000000000002"'
N='"note_id":"00000000-0000-0000-0000-000000000005"'
check 0 "create lead, dnc false ok" $AT ${P}add-record-to-list "{$L,\"entry_values\":{\"stage\":\"New\",\"do_not_contact\":false}}"
check 2 "unknown value shape"       $AT ${P}update-list-entry-by-id "{$X,\"entry_values\":{\"stage\":{\"foo\":1}}}" "cannot check this call"
check 2 "dnc cleared"               $AT ${P}update-list-entry-by-id "{$X,\"entry_values\":{\"do_not_contact\":false}}" "do_not_contact may only be written as true"
check 2 "dnc cleared as string"     $AT ${P}update-list-entry-by-id "{$X,\"entry_values\":{\"do_not_contact\":\"false\"}}"
check 0 "dnc set true"              $AT ${P}update-list-entry-by-id "{$X,\"entry_values\":{\"do_not_contact\":true}}"
check 2 "attribute by ID"           $AT ${P}update-list-entry-by-id "{$X,\"entry_values\":{\"925c1cde-cba6-453e-96f9-5bd8f498d8a3\":\"Ready to Send\"}}" "addressed by ID"
check 0 "update person"             $AT ${P}update-record '{"object":"people","record_id":"00000000-0000-0000-0000-000000000003","values":{"sp_role":"influencer"}}'
check 0 "fill company profile"      $AT ${P}update-record '{"object":"companies","record_id":"00000000-0000-0000-0000-000000000004","values":{"description":"Plumbing and radiant heating in Alameda, CA","primary_location":"1173 Broadway, Alameda, CA, 94501, US","linkedin":"https://www.linkedin.com/company/x"}}'
check 2 "create-list refused"       $AT ${P}create-list '{"name":"x"}' "is denied"
check 2 "update-list refused"       $AT ${P}update-list '{"list":"sales_partner_pipeline"}'
check 2 "delete refused"            $AT ${P}delete-comment '{}' "is denied"
check 2 "merge refused"             $AT ${P}merge-records '{}' "is denied"
check 2 "unlisted tool refused"     $AT ${P}create-comment '{}' "is not in the allow list"
check 0 "read tool allowed"         $AT ${P}list-records-in-list '{"list":"sales_partner_pipeline"}'
check 0 "find notes allowed"        $AT ${P}search-notes-by-metadata '{"parent_record_object":"companies","parent_record_id":"00000000-0000-0000-0000-000000000001"}'
check 0 "read a note allowed"       $AT ${P}get-note-body "{$N}"
check 0 "create a note"             $AT ${P}create-note '{"parent_object":"companies","parent_record_id":"00000000-0000-0000-0000-000000000001","title":"Sales Partner · Research","content":"=== 2026-10-16 · research ==="}'
check 0 "create a talking points note" $AT ${P}create-note '{"parent_object":"companies","parent_record_id":"00000000-0000-0000-0000-000000000001","title":"Sales Partner · Talking Points","content":"=== 2026-10-18 · talking points ==="}'
check 2 "create-note extra key refused" $AT ${P}create-note '{"parent_object":"companies","parent_record_id":"00000000-0000-0000-0000-000000000001","title":"Sales Partner · Talking Points","content":"x","meeting_id":"00000000-0000-0000-0000-000000000009"}' "may not use"
check 0 "append to a note"          $AT ${P}update-note "{$N,\"operation\":{\"type\":\"append\",\"content\":\"=== 2026-10-18 · talking points ===\"}}"
check 2 "prepend refused"           $AT ${P}update-note "{$N,\"operation\":{\"type\":\"prepend\",\"content\":\"x\"}}" "type may only be written as append"
check 2 "retitle refused"           $AT ${P}update-note "{$N,\"updated_title\":\"x\"}" "may not use"
check 2 "append and retitle refused" $AT ${P}update-note "{$N,\"operation\":{\"type\":\"append\",\"content\":\"x\"},\"updated_title\":\"x\"}" "may not use"
check 2 "extra operation key refused" $AT ${P}update-note "{$N,\"operation\":{\"type\":\"append\",\"content\":\"x\",\"mode\":\"replace\"}}" "may not use"
check 2 "delete-note refused"       $AT ${P}delete-note "{$N}" "is denied"
PN='"parent_object":"people","parent_record_id":"00000000-0000-0000-0000-000000000003"'
check 0 "create a possible profiles note" $AT ${P}create-note "{$PN,\"title\":\"Sales Partner · Possible Profiles\",\"content\":\"=== 2026-11-03 · possible profiles ===\"}"
check 2 "non-append operation refused" $AT ${P}update-note "{$N,\"operation\":{\"type\":\"replace\",\"content\":\"x\"}}" "type may only be written as append"
check 0 "write person social fields" $AT ${P}update-record '{"object":"people","record_id":"00000000-0000-0000-0000-000000000003","values":{"instagram":"https://www.instagram.com/example","sp_tiktok":"https://www.tiktok.com/@example","sp_profiles_checked_at":"2026-11-03T12:00:00Z"}}'
check 2 "create-task not allowed"   $AT ${P}create-task '{"content":"x"}' "is not in the allow list"
check 2 "update-task not allowed"   $AT ${P}update-task '{"task_id":"x"}' "is not in the allow list"
out=$(printf '{not json' | python3 -B "$E" "$AT" - x 2>&1); rc=$?
[ "$rc" -eq 2 ] && _report ok "malformed JSON blocks" || _report no "malformed JSON (rc=$rc)"

check 2 "agent can't approve a lead"  $AT ${P}update-list-entry-by-id "{$X,\"entry_values\":{\"stage\":\"Ready to Send\"}}" "stage may only be written as"
check 2 "agent can't mark Contacted"  $AT ${P}update-list-entry-by-id "{$X,\"entry_values\":{\"stage\":\"Contacted\"}}" "stage may only be written as"
check 0 "agent marks Researched"      $AT ${P}update-list-entry-by-id "{$X,\"entry_values\":{\"stage\":\"Researched\"}}"
check 2 "agent can't approve (Approved)" $AT ${P}update-list-entry-by-id "{$X,\"entry_values\":{\"stage\":\"Approved\"}}" "stage may only be written as"
check 2 "Approach Drafted is gone"  $AT ${P}update-list-entry-by-id "{$X,\"entry_values\":{\"stage\":\"Approach Drafted\"}}" "stage may only be written as"
check 0 "agent marks Scored"        $AT ${P}update-list-entry-by-id "{$X,\"entry_values\":{\"stage\":\"Scored\"}}"
check 2 "research_anyway true"      $AT ${P}update-list-entry-by-id "{$X,\"entry_values\":{\"research_anyway\":true}}" "research_anyway may not be written"
check 2 "research_anyway false"     $AT ${P}update-list-entry-by-id "{$X,\"entry_values\":{\"research_anyway\":false}}" "research_anyway may not be written"
check 2 "research_anyway \"true\""   $AT ${P}update-list-entry-by-id "{$X,\"entry_values\":{\"research_anyway\":\"true\"}}" "research_anyway may not be written"
check 2 "research_anyway on create" $AT ${P}add-record-to-list "{$L,\"entry_values\":{\"stage\":\"New\",\"research_anyway\":true}}" "research_anyway may not be written"
check 0 "write segment"             $AT ${P}update-list-entry-by-id "{$X,\"entry_values\":{\"segment\":\"home-services\"}}"
check 0 "write hero_offer"          $AT ${P}update-list-entry-by-id "{$X,\"entry_values\":{\"hero_offer\":\"ps-invoice-reconciliation\"}}"
check 0 "write offer_reason"        $AT ${P}update-list-entry-by-id "{$X,\"entry_values\":{\"offer_reason\":\"Two reviews mention slow invoicing\"}}"
check 0 "write offer_evidence"      $AT ${P}update-list-entry-by-id "{$X,\"entry_values\":{\"offer_evidence\":\"strong\"}}"
check 0 "clear the offer fields"    $AT ${P}update-list-entry-by-id "{$X,\"entry_values\":{\"hero_offer\":[],\"offer_evidence\":[],\"offer_reason\":\"Every offer ruled out\"}}"
check 0 "clear segment"             $AT ${P}update-list-entry-by-id "{$X,\"entry_values\":{\"segment\":[]}}"
check 0 "write research_capped true"  $AT ${P}update-list-entry-by-id "{$X,\"entry_values\":{\"research_capped\":true}}"
check 0 "write research_capped false" $AT ${P}update-list-entry-by-id "{$X,\"entry_values\":{\"research_capped\":false}}"
check 0 "write point of contact"    $AT ${P}update-list-entry-by-id "{$X,\"entry_values\":{\"point_of_contact\":[{\"target_object\":\"people\",\"target_record_id\":\"00000000-0000-0000-0000-000000000003\"}],\"point_of_contact_pick\":[{\"target_object\":\"people\",\"target_record_id\":\"00000000-0000-0000-0000-000000000003\"}],\"point_of_contact_reason\":\"Owner; most senior with an email\"}}"
check 2 "agent can't mark Engaged"    $AT ${P}update-list-entry-by-id "{$X,\"entry_values\":{\"stage\":\"Engaged\"}}" "stage may only be written as"
check 0 "agent disqualifies"          $AT ${P}update-list-entry-by-id "{$X,\"entry_values\":{\"stage\":\"Disqualified\"}}"
check 2 "agent can't open a deal"     $AT ${P}update-list-entry-by-id "{$X,\"entry_values\":{\"stage\":\"Open Deal\"}}" "stage may only be written as"
check 2 "no New on update"            $AT ${P}update-list-entry-by-id "{$X,\"entry_values\":{\"stage\":\"New\"}}" "stage may only be written as"
check 2 "agent can't nurture"         $AT ${P}update-list-entry-by-id "{$X,\"entry_values\":{\"stage\":\"Nurture\"}}" "stage may only be written as"
check 2 "agent can't mark Customer"   $AT ${P}update-list-entry-by-id "{$X,\"entry_values\":{\"stage\":\"Customer\"}}" "stage may only be written as"
check 2 "Replied is gone"             $AT ${P}update-list-entry-by-id "{$X,\"entry_values\":{\"stage\":\"Replied\"}}" "stage may only be written as"
check 2 "lead created past New"       $AT ${P}add-record-to-list "{$L,\"entry_values\":{\"stage\":\"Scored\"}}" "stage may only be written as New on create"
check 0 "lead created at New"         $AT ${P}add-record-to-list "{$L,\"entry_values\":{\"stage\":\"New\"}}"
echo "-- HubSpot"
HS=capabilities/crm/tools/hubspot/guard.yaml; H=mcp__claude_ai_HubSpot__
CU='{"objectType":"companies","objectId":202,"properties":{"sp_do_not_contact":%s}}'
NC='{"objectType":"notes","properties":{"hs_note_body":"%s","hs_timestamp":"2026-10-16T00:00:00Z"},"associations":[{"targetObjectType":"COMPANY","targetObjectId":202}]}'
check 0 "create a talking points note" $HS ${H}manage_crm_objects "{\"createRequest\":{\"objects\":[$(printf "$NC" '<p>=== 2026-10-18 · talking points ===</p><p>For: the business</p>')]}}"
check 0 "create a research note"    $HS ${H}manage_crm_objects "{\"createRequest\":{\"objects\":[$(printf "$NC" '<p>=== 2026-10-16 · research ===</p>')]}}"
NP='{"objectType":"notes","properties":{"hs_note_body":"%s","hs_timestamp":"2026-11-03T00:00:00Z"},"associations":[{"targetObjectType":"CONTACT","targetObjectId":303},{"targetObjectType":"COMPANY","targetObjectId":202}]}'
check 0 "create a possible profiles note" $HS ${H}manage_crm_objects "{\"createRequest\":{\"objects\":[$(printf "$NP" '<p>=== 2026-11-03 · possible profiles ===</p><p>facebook: https://www.facebook.com/example</p>')]}}"
check 2 "possible profiles note rewritten" $HS ${H}manage_crm_objects '{"updateRequest":{"objects":[{"objectType":"notes","objectId":304,"properties":{"hs_note_body":"<p>new</p>"}}]}}' "hs_note_body may not be changed after create"
check 0 "write contact social fields" $HS ${H}manage_crm_objects '{"updateRequest":{"objects":[{"objectType":"contacts","objectId":303,"properties":{"sp_instagram_url":"https://www.instagram.com/example","sp_profiles_checked_at":"2026-11-03T12:00:00Z"}}]}}'
check 2 "note body rewritten"       $HS ${H}manage_crm_objects '{"updateRequest":{"objects":[{"objectType":"notes","objectId":303,"properties":{"hs_note_body":"<p>new</p>"}}]}}' "hs_note_body may not be changed after create"
check 2 "agent can't approve a lead"  $HS ${H}manage_crm_objects '{"updateRequest":{"objects":[{"objectType":"companies","objectId":202,"properties":{"sp_stage":"Ready to Send"}}]}}' "sp_stage may only be written as"
check 2 "agent can't approve (Approved)" $HS ${H}manage_crm_objects '{"updateRequest":{"objects":[{"objectType":"companies","objectId":202,"properties":{"sp_stage":"Approved"}}]}}' "sp_stage may only be written as"
check 2 "Approach Drafted is gone"    $HS ${H}manage_crm_objects '{"updateRequest":{"objects":[{"objectType":"companies","objectId":202,"properties":{"sp_stage":"Approach Drafted"}}]}}' "sp_stage may only be written as"
check 0 "agent marks Researched"      $HS ${H}manage_crm_objects '{"updateRequest":{"objects":[{"objectType":"companies","objectId":202,"properties":{"sp_stage":"Researched"}}]}}'
check 0 "agent marks Scored"          $HS ${H}manage_crm_objects '{"updateRequest":{"objects":[{"objectType":"companies","objectId":202,"properties":{"sp_stage":"Scored"}}]}}'
check 2 "sp_research_anyway true"     $HS ${H}manage_crm_objects '{"updateRequest":{"objects":[{"objectType":"companies","objectId":202,"properties":{"sp_research_anyway":true}}]}}' "sp_research_anyway may not be written"
check 2 "sp_research_anyway false"    $HS ${H}manage_crm_objects '{"updateRequest":{"objects":[{"objectType":"companies","objectId":202,"properties":{"sp_research_anyway":false}}]}}' "sp_research_anyway may not be written"
check 2 "sp_research_anyway \"true\""  $HS ${H}manage_crm_objects '{"updateRequest":{"objects":[{"objectType":"companies","objectId":202,"properties":{"sp_research_anyway":"true"}}]}}' "sp_research_anyway may not be written"
check 2 "sp_research_anyway on create" $HS ${H}manage_crm_objects '{"createRequest":{"objects":[{"objectType":"companies","properties":{"name":"X","sp_stage":"New","sp_research_anyway":"true"}}]}}' "sp_research_anyway may not be written"
check 0 "write sp_segment"            $HS ${H}manage_crm_objects '{"updateRequest":{"objects":[{"objectType":"companies","objectId":202,"properties":{"sp_segment":"home-services"}}]}}'
check 0 "write sp_hero_offer"         $HS ${H}manage_crm_objects '{"updateRequest":{"objects":[{"objectType":"companies","objectId":202,"properties":{"sp_hero_offer":"ps-invoice-reconciliation"}}]}}'
check 0 "write sp_offer_reason"       $HS ${H}manage_crm_objects '{"updateRequest":{"objects":[{"objectType":"companies","objectId":202,"properties":{"sp_offer_reason":"Two reviews mention slow invoicing"}}]}}'
check 0 "write sp_offer_evidence"     $HS ${H}manage_crm_objects '{"updateRequest":{"objects":[{"objectType":"companies","objectId":202,"properties":{"sp_offer_evidence":"strong"}}]}}'
check 0 "clear the sp_ offer fields"  $HS ${H}manage_crm_objects '{"updateRequest":{"objects":[{"objectType":"companies","objectId":202,"properties":{"sp_hero_offer":"","sp_offer_evidence":"","sp_offer_reason":"Every offer ruled out"}}]}}'
check 0 "clear sp_segment"            $HS ${H}manage_crm_objects '{"updateRequest":{"objects":[{"objectType":"companies","objectId":202,"properties":{"sp_segment":""}}]}}'
check 0 "write sp_research_capped true"  $HS ${H}manage_crm_objects '{"updateRequest":{"objects":[{"objectType":"companies","objectId":202,"properties":{"sp_research_capped":"true"}}]}}'
check 0 "write sp_research_capped false" $HS ${H}manage_crm_objects '{"updateRequest":{"objects":[{"objectType":"companies","objectId":202,"properties":{"sp_research_capped":"false"}}]}}'
check 0 "write sp_point_of_contact"   $HS ${H}manage_crm_objects '{"updateRequest":{"objects":[{"objectType":"companies","objectId":202,"properties":{"sp_point_of_contact":"303","sp_point_of_contact_pick":"303","sp_point_of_contact_reason":"Owner; most senior with an email"}}]}}'
check 2 "agent can't mark Contacted"  $HS ${H}manage_crm_objects '{"updateRequest":{"objects":[{"objectType":"companies","objectId":202,"properties":{"sp_stage":"Contacted"}}]}}' "sp_stage may only be written as"
check 0 "agent disqualifies"          $HS ${H}manage_crm_objects '{"updateRequest":{"objects":[{"objectType":"companies","objectId":202,"properties":{"sp_stage":"Disqualified"}}]}}'
check 2 "agent can't mark Engaged"    $HS ${H}manage_crm_objects '{"updateRequest":{"objects":[{"objectType":"companies","objectId":202,"properties":{"sp_stage":"Engaged"}}]}}' "sp_stage may only be written as"
check 2 "agent can't nurture"         $HS ${H}manage_crm_objects '{"updateRequest":{"objects":[{"objectType":"companies","objectId":202,"properties":{"sp_stage":"Nurture"}}]}}' "sp_stage may only be written as"
check 2 "no New on update"            $HS ${H}manage_crm_objects '{"updateRequest":{"objects":[{"objectType":"companies","objectId":202,"properties":{"sp_stage":"New"}}]}}' "sp_stage may only be written as"
check 2 "agent can't open a deal"     $HS ${H}manage_crm_objects '{"updateRequest":{"objects":[{"objectType":"companies","objectId":202,"properties":{"sp_stage":"Open Deal"}}]}}' "sp_stage may only be written as"
check 2 "agent can't mark Customer"   $HS ${H}manage_crm_objects '{"updateRequest":{"objects":[{"objectType":"companies","objectId":202,"properties":{"sp_stage":"Customer"}}]}}' "sp_stage may only be written as"
check 2 "lead created past New"       $HS ${H}manage_crm_objects '{"createRequest":{"objects":[{"objectType":"companies","properties":{"name":"X","sp_stage":"Scored"}}]}}' "sp_stage may only be written as New on create"
DONE=61bafb31-e7fa-46ed-aaa9-1322438d6e67
check 2 "task status written"       $HS ${H}manage_crm_objects '{"updateRequest":{"objects":[{"objectType":"tasks","objectId":101,"properties":{"hs_task_status":"COMPLETED"}}]}}' "hs_task_status may not be written"
check 2 "task created with status"  $HS ${H}manage_crm_objects '{"createRequest":{"objects":[{"objectType":"tasks","properties":{"hs_task_status":"NOT_STARTED"}}]}}' "hs_task_status may not be written"
check 2 "task body written"         $HS ${H}manage_crm_objects '{"updateRequest":{"objects":[{"objectType":"tasks","objectId":101,"properties":{"hs_task_body":"x"}}]}}' "hs_task_body may not be written"
check 2 "task completion date"      $HS ${H}manage_crm_objects '{"updateRequest":{"objects":[{"objectType":"tasks","objectId":101,"properties":{"hs_task_completion_date":"2026-10-16T00:00:00Z"}}]}}' "hs_task_completion_date may not be written"
check 2 "note re-dated"             $HS ${H}manage_crm_objects '{"updateRequest":{"objects":[{"objectType":"notes","objectId":303,"properties":{"hs_timestamp":"2027-01-01T00:00:00Z"}}]}}' "hs_timestamp may not be changed after create"
check 2 "hs_pipeline_stage blocked" $HS ${H}manage_crm_objects "{\"updateRequest\":{\"objects\":[{\"objectType\":\"companies\",\"objectId\":202,\"properties\":{\"hs_pipeline_stage\":\"$DONE\"}}]}}" "hs_pipeline_stage may not be written"
check 2 "hs_pipeline blocked"       $HS ${H}manage_crm_objects '{"updateRequest":{"objects":[{"objectType":"companies","objectId":202,"properties":{"hs_pipeline":"3d314325-1b2a-4225-9388-375f49c57ec3"}}]}}' "hs_pipeline may not be written"
check 0 "dnc set \"true\""          $HS ${H}manage_crm_objects "{\"updateRequest\":{\"objects\":[$(printf "$CU" '"true"')]}}"
check 0 "dnc set true"              $HS ${H}manage_crm_objects "{\"updateRequest\":{\"objects\":[$(printf "$CU" true)]}}"
check 2 "dnc cleared \"false\""     $HS ${H}manage_crm_objects "{\"updateRequest\":{\"objects\":[$(printf "$CU" '"false"')]}}" "sp_do_not_contact may only be written as true"
check 2 "dnc cleared false"         $HS ${H}manage_crm_objects "{\"updateRequest\":{\"objects\":[$(printf "$CU" false)]}}"
check 0 "create lead at New"        $HS ${H}manage_crm_objects '{"createRequest":{"objects":[{"objectType":"companies","properties":{"name":"X","sp_stage":"New"}}]}}'
check 2 "custom properties refused" $HS ${H}manage_custom_properties '{}' "is not in the allow list"
check 2 "marketing email refused"   $HS ${H}manage_marketing_email '{}' "is not in the allow list"
check 2 "delete refused"            $HS ${H}delete_crm_objects '{}' "is denied"
check 2 "merge refused"             $HS ${H}merge_crm_objects '{}' "is denied"
check 0 "search allowed"            $HS ${H}search_crm_objects '{"objectType":"NOTE"}'
check 0 "local server name allowed" $HS mcp__HubSpot__search_crm_objects '{"objectType":"COMPANY"}'
# Token canary, offline: call is faked to fail (a 401, then a raised Stop); all output is captured.
export CATALOG_FIXTURE="$PWD/tests/fixtures/offer-catalog.md"
canary=$(python3 -B - <<'PY' 2>&1
import importlib.util, io, os, contextlib
sp = importlib.util.spec_from_file_location("b", "capabilities/crm/tools/hubspot/bootstrap.py")
b = importlib.util.module_from_spec(sp); sp.loader.exec_module(b)
os.environ["HUBSPOT_TOKEN"] = "sk-canary-12345"

def unauthorized(token, method, path, body=None):
    return 401, {"message": "Authentication credentials not found."}

def unreachable(token, method, path, body=None):
    raise b.Stop("cannot reach HubSpot: offline")

for name, fake in (("401", unauthorized), ("stop", unreachable)):
    b.call = fake
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf), contextlib.redirect_stderr(buf):
        rc = b.main(["--catalog", os.environ["CATALOG_FIXTURE"]])
    print(f"[{name}] rc={rc}")
    print(buf.getvalue())
PY
)
printf '%s' "$canary" | grep -qF '[401] rc=1' && printf '%s' "$canary" | grep -qF '[stop] rc=1' \
  && _report ok "bootstrap canary: a failing call stops with exit 1, offline" || _report no "bootstrap canary did not run as expected ($canary)"
printf '%s' "$canary" | grep -q 'sk-canary-12345' && _report no "bootstrap echoed the token" || _report ok "bootstrap never prints the token"
grep -q 'print(.*token' capabilities/crm/tools/hubspot/bootstrap.py && _report no "bootstrap prints a token variable" || _report ok "no print of the token"

# bootstrap.py: pass 1 checks existing property types offline (call is faked; no network)
bt=$(python3 -B - <<'PY' 2>&1
import importlib.util, io, contextlib
sp = importlib.util.spec_from_file_location("b", "capabilities/crm/tools/hubspot/bootstrap.py")
b = importlib.util.module_from_spec(sp); sp.loader.exec_module(b)
import os
os.environ["HUBSPOT_TOKEN"] = "t"
CATALOG = os.environ["CATALOG_FIXTURE"]
# The same function main() calls, fed the same fixture main() is given below.
b.PROPERTIES = b.build_properties(*b.read_catalog(CATALOG))

def defn(obj, name):
    return next(p for p in b.PROPERTIES[obj] if p["name"] == name)

def run(over):
    calls = []
    def fake(token, method, path, body=None):
        calls.append((method, path))
        parts = path.strip("/").split("/")
        if method == "GET" and len(parts) == 3 and parts[1] == "groups":
            return 200, {}
        if method == "GET":
            have = over.get(path)
            if have == 404:
                return 404, {"message": "nf"}
            if have is not None:
                return 200, have
            d = defn(parts[0], parts[1])
            return 200, {k: d[k] for k in ("type", "fieldType", "options") if k in d}
        return 200, {}
    b.call = fake
    out, err = io.StringIO(), io.StringIO()
    with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
        rc = b.main(["--catalog", CATALOG])
    writes = [c for c in calls if c[0] in ("POST", "PATCH")]
    return rc, out.getvalue() + err.getvalue(), writes

rc, text, w = run({"/companies/sp_stage": {"type": "string", "fieldType": "text"}})
print("A", rc == 1 and "companies.sp_stage exists as string/text but must be enumeration/select" in text
      and "Company properties" in text and not w)
rc, text, w = run({})
print("B", rc == 0 and not w)
rc, text, w = run({"/companies/sp_fit_score": 404})
print("C", rc == 0 and w == [("POST", "/companies")])
rc, text, w = run({"/contacts/sp_role": {"type": "enumeration", "fieldType": "select",
                   "options": [{"value": "decision-maker"}, {"value": "extra"}]}})
print("D", rc == 0 and [m for m, _ in w] == ["PATCH"])

rc, text, w = run({"/companies/sp_stage": {"type": "enumeration", "fieldType": "select",
                   "options": [{"value": v} for v in b.STAGES + ["Approach Drafted", "Ready to Send"]]}})
print("F", rc == 0 and not w and "companies.sp_stage: extra options left in place (archive by hand if unwanted)" in text
      and "Approach Drafted" in text and "Ready to Send" in text)

# E: a realistic HubSpot GET payload for every property: extra fields, real type/fieldType pairs.
META = {"archivable": True, "readOnlyDefinition": False, "readOnlyValue": False}
def realistic(d):
    p = {"updatedAt": "2026-09-01T12:00:00.000Z", "createdAt": "2026-09-01T12:00:00.000Z",
         "name": d["name"], "label": d["label"], "type": d["type"], "fieldType": d["fieldType"],
         "description": "", "groupName": "sales_partner", "options": [],
         "createdUserId": "1234567", "updatedUserId": "1234567", "displayOrder": -1,
         "calculated": False, "externalOptions": False, "archived": False,
         "hasUniqueValue": False, "hidden": False, "formField": True,
         "dataSensitivity": "non_sensitive", "modificationMetadata": META}
    for i, o in enumerate(d.get("options", [])):
        p["options"].append({"label": o["label"], "value": o["value"], "description": "",
                             "displayOrder": i, "hidden": False})
    return p
pairs = {(p["type"], p["fieldType"]) for ps in b.PROPERTIES.values() for p in ps}
real = {f"/{o}/{p['name']}": realistic(p) for o, ps in b.PROPERTIES.items() for p in ps}
rc, text, w = run(real)
print("E", rc == 0 and not w and pairs == {("enumeration", "select"), ("datetime", "date"),
      ("string", "textarea"), ("number", "number"), ("string", "text"), ("date", "date"),
      ("bool", "booleancheckbox")})
PY
)
for c in A:"mismatched type blocks with a clear message and no writes" B:"correct types pass with no writes" \
         C:"a missing property is created" D:"missing enum options are patched, extras kept" \
         E:"a realistic HubSpot property payload passes with no writes" \
         F:"old stages left in place are reported, not removed"; do
  k=${c%%:*}; echo "$bt" | grep -qx "$k True" && _report ok "bootstrap $k: ${c#*:}" || _report no "bootstrap $k: ${c#*:} ($bt)"
done

echo "-- web_search (exa)"
EX=capabilities/web_search/tools/exa/guard.yaml; P=mcp__ExaSearch__; SM=exasearch  # the cloud routine's name (probe note)
check 0 "search with query"          $EX ${P}web_search_exa '{"query":"owner or principal of a roofing contractor in Alameda"}'
check 0 "category in the query"      $EX ${P}web_search_exa '{"query":"category:people owner of a roofing contractor in Alameda"}'
check 2 "numResults blocked"         $EX ${P}web_search_exa '{"query":"x","numResults":100}' "may not use numResults"
check 2 "respelled numresults"       $EX ${P}web_search_exa '{"query":"x","numresults":100}' "may not use"
check 2 "agent_run blocked"          $EX ${P}agent_run '{"query":"x"}'
check 2 "advanced search blocked"    $EX ${P}web_search_advanced_exa '{"query":"x"}'
check 2 "page fetch blocked"         $EX ${P}web_fetch_exa '{"urls":["https://example.com"]}'
check 0 "query with objective"       $EX ${P}web_search_exa '{"query":"owner or principal of a roofing contractor in Alameda","objective":"Find the owner or principal of this business"}'
check 2 "objective with numResults"  $EX ${P}web_search_exa '{"query":"x","objective":"y","numResults":100}' "may not use numResults"
check 0 "local session name"         $EX mcp__claude_ai_ExaSearch__web_search_exa '{"query":"owner of a roofing contractor in Alameda"}'
SM=

finish
