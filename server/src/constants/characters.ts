export interface Character {
    id: string;
    name: string;
    price: number;
    description: string;
    lite: {
        primaryColor: string;
        accentColor: string;
    };
    full: {
        src: string;
        stateMachine: string;
    };
    ultra: {
        idle: string[];
        selection: string[];
        rock: string[];
        paper: string[];
        scissors: string[];
    };
}

export const CHARACTER_CATALOG: Character[] = [
    {
        id: 'default',
        name: 'The Original',
        price: 0,
        description: 'The classic Roshambo experience. Sleek, blue, and balanced.',
        lite: {
            primaryColor: '#3b82f6', // blue-500
            accentColor: '#60a5fa'  // blue-400
        },
        full: {
            src: 'https://cdn.rive.app/animations/vehicles.riv',
            stateMachine: 'bumpy'
        },
        ultra: {
            idle: ['idle1.mp4'],
            selection: ['selection1.mp4'],
            rock: ['rock1.mp4'],
            paper: ['paper1.mp4'],
            scissors: ['scissors1.mp4']
        }
    },
    {
        id: 'neon_vandal',
        name: 'Neon Vandal',
        price: 50,
        description: 'A high-stakes aesthetic with vibrant pinks and electric purples.',
        lite: {
            primaryColor: '#ec4899', // pink-500
            accentColor: '#f472b6' // pink-400
        },
        full: {
            src: 'https://cdn.rive.app/animations/vehicles.riv', // placeholder
            stateMachine: 'bumpy'
        },
        ultra: {
            idle: ['idle1.mp4'], // placeholders for now
            selection: ['selection1.mp4'],
            rock: ['rock1.mp4'],
            paper: ['paper1.mp4'],
            scissors: ['scissors1.mp4']
        }
    },
    {
        id: 'chrome_sentinel',
        name: 'Chrome Sentinel',
        price: 150,
        description: 'Industrial minimalism. Polished steel and cold white glares.',
        lite: {
            primaryColor: '#94a3b8', // slate-400
            accentColor: '#f8fafc' // slate-50
        },
        full: {
            src: 'https://cdn.rive.app/animations/vehicles.riv', // placeholder
            stateMachine: 'bumpy'
        },
        ultra: {
            idle: ['idle1.mp4'], // placeholders for now
            selection: ['selection1.mp4'],
            rock: ['rock1.mp4'],
            paper: ['paper1.mp4'],
            scissors: ['scissors1.mp4']
        }
    }
];
