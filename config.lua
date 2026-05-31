fd = {}
locales = {}

fd.locale = 'en'

fd.notifysystem = 'ox_lib' -- 'esx' | 'ox_lib' | 'lb-phone'
fd.interaction = 'target' -- 'target' | 'textui'

fd.paymentmethod = 'pickup' -- 'bank' | 'pickup' (Bank = Method used in older versions)
fd.pickupaccount = 'cash'
fd.paycheckcron = 1

fd.defaultpay = 500
fd.usedatabase = true

fd.enabletaxes = true
fd.taxrate = 10

fd.deductfromsociety = true -- Requires esx_society
fd.societybypass = { 'unemployed' }

fd.antiafk = true
fd.afkdistance = 5.0
fd.afktime = 20

fd.enableexpiration = true
fd.expirationtime = 7
fd.expirationaction = 'return'

fd.pedmodel = 'ig_bankman'
fd.pickuplocation = vec3(252.9017, 223.0579, 106.2868)
fd.pickuplocationheading = 161.1427

fd.enableblip = true
fd.blipname = 'Pacific Bank'
fd.blipsprite = 207
fd.blipcolor = 3

fd.jobs = {
    -- ['police'] = {
    --     [0] = 3000,
    --     [1] = 3500,
    --     [2] = 4000,
    --     [3] = 4500,
    --     [4] = 5000,
    --     [5] = 5500
    -- },
    -- ['unemployed'] = 250
}
