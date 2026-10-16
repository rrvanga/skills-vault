# Spousal / Spouse-Partner Stream — Verified Detail (inland)

Scenario this was transcribed for: sponsor = Canadian PR, applicant = Indian citizen living in Canada on a work permit, **no dependants**, applying under the **Spouse or Common-Law Partner in Canada class** (inland). Sources: IMM 5533 (Document Checklist — Spouse, 09-2022) text, and the generated block on `https://ircc.canada.ca/english/information/applications/spouse.asp`. Anything below that is not marked verified must be re-read from the live source before being quoted to the user.

## Kit-page JS recipe (works, verified)

```python
# browser_exec, dedicated session for ircc
r = js("""(() => {
 const S=(id,txt)=>{const el=document.getElementById(id);
   const o=Array.from(el.options).find(o=>o.text.trim().toLowerCase()===txt.toLowerCase());
   if(!o) return id+':MISS'; el.value=o.value;
   el.dispatchEvent(new Event('change',{bubbles:true})); return id+':ok';};
 return [S('wb-auto-12','My spouse (and dependent children, if this applies)'),
         S('wb-auto-249','Canada'),
         S('wb-auto-488','India')].join(' | ');
})()""")
time.sleep(3)
js("""(() => {const b=Array.from(document.querySelectorAll('input,button'))
  .find(x=>/get checklist and forms/i.test(x.value||x.innerText||''));
  if(b){b.click();return 'clicked';} return 'no btn';})()""")
time.sleep(6)
t = js("document.body.innerText")          # write to a file, then grep 'Country specific requirements'
```

- The `wb-auto-*` ids above are per-render; re-read the ids from the DOM first (or locate the selects by their preceding label text) — never hard-code them across sessions.
- Select index meanings on this page (stable): [0] relationship, [1] country of residence, [2] "Country or territory:" (documents-issuing country), [3]/[4] extra countries (default "This doesn't apply to me").
- The results block appears BELOW the form, under the heading `Get your checklist, forms and instructions`; `t.find('Country specific requirements')` is the reliable anchor.

## Part A — forms (verified from IMM 5533)

1. **IMM 5533** — the checklist itself; must be uploaded.
2. **IMM 1344** — Application to Sponsor, Sponsorship Agreement and Undertaking; signed by sponsor AND sponsored person; PDF of the digitally signed original uploaded.
3. **Application fees** — one receipt covering sponsorship + application + biometric fees; RPRF recommended upfront.
4. **IMM 1283** (Financial Evaluation) — only if the sponsored spouse has a dependent child who has their own dependent child. Not applicable for a childless couple.
5. **Class of Application** — the inland box: "I am currently living in Canada with my sponsor, and I am applying under the Spouse or Common-Law Partner in Canada Class."
6. **IMM 0008** — Generic Application Form (digital, completed online).
7. **Country specific requirements** — confirm review, list any extra forms or write N/A.
8. **IMM 5406** — Additional Family Information (applicant + family members 18+ who are not already PR/citizens).
9. **IMM 5669** — Schedule A, Background/Declaration (digital).
10. **IMM 5532** — Relationship Information and Sponsorship Evaluation; sponsor signs Part A #9 and Part C #12, applicant signs Part B #5 and Part C #13.
11. **IMM 5476** — Use of a Representative (only if appointing one; if the sponsor acts as representative, each adult files their own IMM 5476 or the application is returned).
12. **IMM 5475** — Authority to Release Personal Information to a Designated Individual (only if applicable).

## Part B — sponsor documents (verified)

- **Status in Canada**: PR card photocopy, both sides, or CoPR/eCoPR; an expired card copy is acceptable. (Citizen path: citizenship certificate/card both sides, pre-1977 photo-less citizenship card, Canadian birth certificate, or passport bio page.)
- **Citizen living outside Canada** → proof of intent to live in Canada with the spouse. (Not applicable to a PR sponsor.)
- **Child with a claim to Canadian citizenship**: if yes, include that child's Canadian birth certificate / passport bio page / citizenship certificate — the application is NOT returned for omitting it, but a Canadian citizen child cannot be sponsored.
- **Previous relationships**: if previously married → final divorce certificate, annulment certificate, or former spouse's death certificate; if legally separated → proof of separation (tax forms, legal documents); prior sponsorship → sponsor's name and DOB.
- **Employment / source of income** (skip if Quebec resident): employer letter stating period of employment, salary and regular hours per week, or self-employment financial documents, AND most recent CRA **Notice of Assessment showing line 15000 (Total Income)** or **Proof of Income Statement (Option C)**. Missing both → written explanation plus supporting financial evidence demonstrating ability to support.

## Sponsored-person section — NOT yet transcribed

IMM 5533 Part B "Supporting documents for sponsored persons (principal applicant and all family members)" occupies roughly lines 332-698 of the condensed `imm5533e.txt`. Re-extract with `scripts/ircc_forms_extract.py <txt> --grep "SUPPORTING DOCUMENTS FOR SPONSORED"` before answering identity/civil-status, police-certificate, photo or medical questions. Do not fill this gap from memory.

## Country-specific — India (verified, from the generated kit block)

- Send **photocopies** unless instructed otherwise.
- Adoption via customary law (Indian passport child): explanation + adoption deed, ceremony photographs, power of attorney, proof of contact/financial support, CARA no-objection letter, and a CARA + provincial declaration of Hague Convention compliance.
- **Birth certificates**: if the birth was registered late, include a copy of the original baptism certificate plus copies of other original identity documents — old school records (Fifth class, Middle standard, Matriculation/secondary school certificate) and Voter's ID card.
- **Divorces obtained in India**: submit copies of the complete divorce petition, the judgment, and the final divorce decree.
- Canada block for the same application: "no extra forms" and "no special instructions for documents".

## Inland-specific notes

- Living in Canada with the sponsor is the eligibility condition for the in-Canada class; an applicant applying under the Family Class while in Canada may be called to an interview at a visa office outside Canada (that is a separate box on the checklist).
- An applicant living in Canada with the sponsor may apply for an **open work permit** with the PR application (own fee, submitted online with the package). A valid existing work permit stays valid while the PR application is processed.
- Biometrics are generally required (ages 14-79), fee paid at submission, and must be given within 30 days of the instruction letter.
- One photo per person; both sides scanned and uploaded.
- Quebec: separate provincial undertaking and fees, and the sponsor income section of the checklist is skipped — ask before assuming.
- Incomplete applications are rejected, not merely delayed.
