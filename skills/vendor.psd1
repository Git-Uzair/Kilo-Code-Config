# Third-party skills vendored into skills/<name>/ by scripts/sync-skills.ps1.
# Edit this file, run the script, review `git diff -- skills`, commit.
# Never hand-edit a vendored folder: the next sync overwrites it.
# Drop a skill: delete its line here, then `git rm -r skills/<name>`.
# Local skills (codebase-map) are not listed; the script never touches them.
@{
    Sources      = @(
        @{
            Repo         = 'https://github.com/mattpocock/skills'
            Commit       = '4ae2317ddb22b046e26455e4f9c9b3aaaf62212d'
            LicenseFiles = @('LICENSE')                        # MIT
            Skills       = @{
                'tdd'                = 'skills/engineering/tdd'                 # replaces superpowers test-driven-development
                'codebase-design'    = 'skills/engineering/codebase-design'     # hard dependency of tdd
                'diagnosing-bugs'    = 'skills/engineering/diagnosing-bugs'     # replaces systematic-debugging
                'domain-modeling'    = 'skills/engineering/domain-modeling'     # hard dependency of grill-with-docs
                'grill-with-docs'    = 'skills/engineering/grill-with-docs'     # attended design interview
                'retro'              = 'skills/engineering/retro'               # post-run review of the harness
                'grilling'           = 'skills/productivity/grilling'           # hard dependency of grill-with-docs
                'writing-for-agents' = 'skills/productivity/writing-for-agents' # replaces skill-creator; hard dependency of retro
            }
        },
        @{
            Repo         = 'https://github.com/JuliusBrussee/caveman'
            Commit       = '2e068f735253cce28256744804785f01887d9646'
            LicenseFiles = @('LICENSE', 'NOTICE', 'LICENSE-MIT') # Apache-2.0; NOTICE and the pre-3.0 MIT text must travel
            Skills       = @{
                'caveman'   = 'skills/caveman'   # terse reply voice, user-typed /caveman
                'ultracave' = 'skills/ultracave' # hard dependency of caveman (/caveman ultra)
                'megacave'  = 'skills/megacave'  # hard dependency of caveman (/caveman wenyan)
            }
        },
        @{
            Repo         = 'https://github.com/DietrichGebert/ponytail'
            Commit       = '96608e078b2d5ea607c5c3b8b5a54d1c1fba6846'
            LicenseFiles = @('LICENSE')                        # MIT
            Skills       = @{
                'ponytail'        = 'skills/ponytail'
                'ponytail-review' = 'skills/ponytail-review'
            }
        },
        @{
            Repo         = 'https://github.com/anthropics/skills'
            Commit       = 'ca45fc496a3436251f191354091d557da31c15b5'
            LicenseFiles = @()                                 # Apache-2.0 LICENSE.txt ships inside the folder
            Skills       = @{
                'frontend-design' = 'skills/frontend-design'
            }
        }
    )

    # References the closure check accepts without shipping the target.
    # Every entry needs its reason.
    Acknowledged = @{
        'tdd'          = @('code-review')      # "see the code-review skill" about refactoring; review here is the ponytail-review skill
        'caveman'      = @('caveman-compress') # named only as an exemption from the voice rules
        'ultracave'    = @('caveman-compress') # same exemption clause
        'megacave'     = @('caveman-compress') # same exemption clause
        'codebase-map' = @('triage')           # kopipasta's "triage" mode in a JSON example, not a skill
    }
}
