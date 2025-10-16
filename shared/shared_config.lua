Config = {}

-- Base locale used for UI texts and notifications.
Config.Locale = 'en' -- da/en

-- Command/Keybind configuration for opening the tuner.
Config.Command = {
    enabled = true,
    name = 'kexhaust',
    defaultKey = 'F7',
    allowKeyMapping = true
}

-- Default exhaust state applied when nothing has been saved yet.
Config.DefaultState = {
    valveMode = 'auto',
    autoStrategy = 'rpm',
    tone = 50,
    volume = 70,
    burble = 30,
    crackle = 20,
    idle = 40
}

-- Safety limits to prevent abuse – all slider values are clamped to these ranges.
Config.Limits = {
    tone = { min = 0, max = 100 },
    volume = { min = 0, max = 100, cap = 85 },
    burble = { min = 0, max = 100, cap = 75 },
    crackle = { min = 0, max = 100, cap = 65 },
    idle = { min = 0, max = 100, cap = 80 }
}

-- Valve modes & auto strategies – values are kept language agnostic while labels live in locales.
Config.ValveModes = {
    order = { 'auto', 'open', 'closed' },
    labels = {
        auto = { da = 'Auto', en = 'Auto' },
        open = { da = 'Åben', en = 'Open' },
        closed = { da = 'Lukket', en = 'Closed' }
    }
}

Config.AutoStrategies = {
    order = { 'rpm', 'speed', 'timed' },
    labels = {
        rpm = { da = 'Auto (Omdr./Belastning)', en = 'Auto (RPM/Load)' },
        speed = { da = 'Auto (Hastighed)', en = 'Auto (Speed)' },
        timed = { da = 'Auto (Tidsbaseret)', en = 'Auto (Timer)' }
    }
}

-- Presets available inside the UI. Values follow the slider scale (0-100).
Config.Presets = {
    order = { 'quiet', 'sport', 'track', 'show' },
    defaultPrimary = 'sport',
    labels = {
        quiet = { da = 'Stille', en = 'Quiet' },
        sport = { da = 'Sport', en = 'Sport' },
        track = { da = 'Bane', en = 'Track' },
        show = { da = 'Show', en = 'Show' }
    },
    data = {
        quiet = { tone = 40, volume = 35, burble = 5, crackle = 0, idle = 25 },
        sport = { tone = 55, volume = 70, burble = 30, crackle = 20, idle = 40 },
        track = { tone = 45, volume = 85, burble = 55, crackle = 40, idle = 55 },
        show = { tone = 65, volume = 85, burble = 75, crackle = 65, idle = 60 }
    }
}

-- Maps tone levels to existing GTA sound sets.
Config.AudioProfiles = {
    { maxTone = 25, sound = 'dominator' },
    { maxTone = 50, sound = 'sultanrs' },
    { maxTone = 75, sound = 'comet' },
    { maxTone = 100, sound = 'italigtb' }
}

-- Audio multipliers for subtle variation. Values are intentionally conservative.
Config.AudioTuning = {
    volumePressure = { min = 0.05, max = 0.65 },
    idleRpm = { min = 0.25, max = 0.6 },
    burbleTurbo = { min = 0.0, max = 0.9 },
    crackleIntensity = { min = 0.0, max = 0.85 }
}

-- Automatically reapply the player's saved profile when they enter a new vehicle as the driver.
Config.AutoApplySavedProfile = true

-- Interval (ms) for pruning stale vehicle states server-side. Set to 0 to disable.
Config.StateCleanupInterval = 60000

-- Locale strings – add further languages by following the same structure.
Config.Locales = {
    da = {
        ui = {
            headerPath = 'Klobow Audio • Exhaust Module',
            title = 'K-Exhaust Tuner',
            labels = {
                valveMode = 'Ventiltilstand',
                autoStrategy = 'Auto strategi',
                tone = 'Tone (mørk → lys)',
                volume = 'Udstødningsvolumen',
                burble = 'Burble intensitet',
                crackle = 'Crackle længde',
                idle = 'Tomgangs lydstyrke'
            },
            help = {
                tone = 'Changer "klang"/fremtoning. 0% = dyb/boomy • 100% = lys/raspy',
                burble = 'Off-throttle & decel pops',
                crackle = 'Hvor længe efter gas-slip'
            },
            buttons = {
                save = 'Gem profil',
                apply = 'Anvend'
            },
            toasts = {
                profileSaved = 'Profil gemt',
                applied = 'Indstillinger anvendt',
                trimmed = 'Nogle værdier blev justeret af sikkerhedssystemet'
            }
        },
        notifications = {
            noVehicle = 'Du skal være i et køretøj for at bruge tuneren.',
            driverOnly = 'Du skal sidde på førersædet.',
            applied = 'Udstødningsprofilen er aktiveret.',
            profileSaved = 'Din udstødningsprofil er gemt server-side.',
            valuesTrimmed = 'Følgende værdier blev sænket: {fields}'
        },
        command = {
            description = 'Åbn Klobow Exhaust tuneren'
        }
    },
    en = {
        ui = {
            headerPath = 'Klobow Audio • Exhaust Module',
            title = 'K-Exhaust Tuner',
            labels = {
                valveMode = 'Valve mode',
                autoStrategy = 'Auto strategy',
                tone = 'Tone (dark → bright)',
                volume = 'Exhaust volume',
                burble = 'Burble intensity',
                crackle = 'Crackle length',
                idle = 'Idle loudness'
            },
            help = {
                tone = 'Changes the colour/character of the sound. 0% = deep/boomy • 100% = bright/raspy',
                burble = 'Off-throttle & deceleration pops',
                crackle = 'How long the crackle continues after throttle lift'
            },
            buttons = {
                save = 'Save profile',
                apply = 'Apply'
            },
            toasts = {
                profileSaved = 'Profile saved',
                applied = 'Settings applied',
                trimmed = 'Some values were reduced by the safety system'
            }
        },
        notifications = {
            noVehicle = 'You need to be in a vehicle to use the tuner.',
            driverOnly = 'You need to be in the driver seat.',
            applied = 'Exhaust profile activated.',
            profileSaved = 'Your exhaust profile has been saved server-side.',
            valuesTrimmed = 'The following values were lowered: {fields}'
        },
        command = {
            description = 'Open the Klobow Exhaust tuner'
        }
    }
}

