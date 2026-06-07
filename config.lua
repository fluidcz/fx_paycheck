fd = {}
Locales = {}

fd.locale = 'en'

fd.notifysystem = 'ox_lib' -- 'esx' | 'ox_lib' | 'lb-phone'
fd.interaction = 'target' -- 'target' | 'textui'

fd.paymentmethod = 'pickup' -- 'bank' | 'pickup' (Bank = Method used in older versions)
fd.pickupaccount = 'bank' -- 'bank' | 'cash'
fd.paycheckcron = 1 -- How often players receive their paycheck

fd.defaultpay = 200
fd.usedatabase = true -- Automatically fetches all jobs and salaries from database

fd.enabletaxes = true
fd.basetax = 10
fd.hidetax = false -- Hides the tax rate from notifications

fd.deductfromsociety = true -- Requires esx_society
fd.societybypass = { 'unemployed', 'police', 'sheriff', 'ambulance' } -- Which jobs will bypass the fd.deductfromsociety option

fd.antiafk = true
fd.afkdistance = 5.0
fd.afktime = 20 -- Minutes

fd.enableexpiration = true
fd.expirationtime = 7
fd.expirationaction = 'return'

fd.pedmodel = 'ig_bankman'
fd.pickuplocation = vec3(252.9017, 223.0579, 106.2868)
fd.pickuplocationheading = 161.1427

fd.enableblip = true -- Blip will be created only if fd.paymentmethod = 'pickup'
fd.blipname = 'Pacific Bank'
fd.blipsprite = 207
fd.blipcolor = 3

fd.jobs = {
    ['police'] = {
        [0] = { pay = 0, tax = 15, label = 'Police Paycheck' },
        [1] = { pay = 0, tax = 10, label = 'Police Paycheck' }
    },
    ['unemployed'] = {
        [0] = { pay = 0, tax = 0, label = 'Social Benefit' }
    }
}
