import { io } from 'socket.io-client'
const URL = 'https://zzaw22ugpq.us-east-1.awsapprunner.com'
const log = (...a) => console.log(new Date().toISOString().slice(11,19), ...a)
const s = io(URL, { auth: {} })
let dev = null, thrownFor = -1, round = -1
s.on('connect_error', e => log('connect_error:', e.message))
s.on('connect', () => s.emit('claim-device'))
s.on('device-claimed', d => { dev = d.deviceId; log('claimed', dev.slice(0,8)); s.emit('sync-player') })
s.on('init', d => { round = d.roundCount; log('init', d.phase, 'round', round) })
s.on('player-data', d => log('PLAYER-DATA pts', d.user.totalPoints, 'pot', d.user.pointsAtStake, 'streak', d.user.stakingStreak, 'last', JSON.stringify(d.user.lastResult ?? null)))
s.on('sync', d => {
  round = d.roundCount
  if (dev && d.phase === 'OPEN' && d.timeLeft > 3 && thrownFor !== round) {
    thrownFor = round
    const pick = ['R','P','S'][(round + 1) % 3]   // TEST_MODE world = index round%3; pick what beats it
    const beats = { R: 'P', P: 'S', S: 'R' }
    const world = ['R','P','S'][round % 3]
    s.emit('submit-throw', { throw: beats[world] })
    log('round', round, 'world will be', world, '-> throwing', beats[world])
  }
})
s.on('reveal', d => log('REVEAL world', d.worldThrow, 'players', d.totalPlayers, JSON.stringify(d.distribution)))
setTimeout(() => { log('banking'); s.emit('bank') }, 200000)
setTimeout(() => { log('exit'); process.exit(0) }, 215000)
