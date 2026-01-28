Config = {}

Config.Locale = 'de' 

Config.PawnPed = {
    model = `a_m_m_business_01`,
    coords = vec4(844.8571, -902.8331, 25.2515, 279.3429),
}

Config.VehicleZones = {
    DropOff = { coords = vec3(852.5704, -906.1911, 25.2933), radius = 3.0 },
    Spawn = { coords = vec3(852.8665, -902.7576, 25.3027), heading = 270.2902 }
}

Config.Preview = {
    coords = vec4(852.8665, -902.7576, 25.3027, 270.2902), 
    camRadius = 6.0,
    camHeight = 1.2,
    rotationSpeed = 0.15
}

Config.InterestRate = 1.25
Config.PayoutRate = 0.70
Config.MaxPawnTime = 14 -- 14 days
Config.PublicMarkup = 1.10

Config.AllowedItems = {
    ['phone'] = { 
        label = 'Smartphone', 
        value = 500, 
        icon = 'mobile-screen-button',
        category = 'Elektronik' 
    },
    ['kuz_watch'] = { 
        label = 'Luxusuhr', 
        value = 2500, 
        icon = 'clock', 
        category = 'Wertsachen' 
    },
    ['tablet'] = { 
        label = 'Tablet', 
        value = 1200, 
        icon = 'mobile-screen-button', 
        category = 'Elektronik' 
    }
}

Config.VehicleDefaultValue = 20000 
Config.VehicleValues = {
    [`panto`] = 2000,
    [`entity2`] = 250000,
    [`t20`] = 180000,
    [`kuruma`] = 45000,
}

Config.BlacklistedVehicles = {
    [`police`] = true,
    [`ambulance`] = true,
}