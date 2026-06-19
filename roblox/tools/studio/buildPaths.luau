-- ZenDojo CANYON PATHS — run via MCP execute_luau in EDIT mode.
-- Lays the circulation network as FLAT-PAVER STEPS (stone treads + risers) following a
-- smooth Catmull-Rom spline through the route markers, with turning platforms at the
-- switchbacks, drop-side timber rails + invisible fall barriers, lanterns, and plank
-- bridge stubs. The walkway IS flat-topped treads (no angled ramps, no carved voxels) —
-- the look the user signed off on. Mirrors the pure logic in tools/builders/CanyonPath.luau
-- (Studio can't require repo modules; keep them in sync).
--
-- KEY: riser cap — every step rises <= STEPH (1.25) studs, so steep stretches get MORE
-- steps rather than un-climbable tall ones (Roblox auto-steps only ~2 studs).
--
-- PATHS/BRIDGES below are a BAKED SNAPSHOT of workspace.PathDraft (2026-06-19 checkpoint,
-- markers still being refined). Re-bake with tools/studio/bakePathMarkers.luau after
-- moving markers, paste the result here, and re-run. Idempotent: rebuilds RoshamboStage.CanyonPaths.
local PATHS = {
  { name="NearWall", wall=1, points={ {-20.0,121.5,46.2},{76.0,145.0,84.5},{4.0,160.8,92.0},{-68.0,171.0,50.7},{-122.0,177.2,78.0},{-176.0,185.1,78.0},{-215.6,193.7,56.4},{-183.4,225.7,103.2},{-241.0,223.0,53.9},{-249.0,224.0,53.2},{-274.0,225.0,76.2},{-324.8,221.0,89.0},{-364.8,218.1,62.2},{-401.9,230.5,55.0} } },
  { name="Floor", wall=0, points={ {-44.7,116.7,26.4},{-83.7,142.1,28.5},{-130.0,150.9,17.1},{-167.5,159.4,27.9},{-213.9,168.8,34.9},{-263.5,181.8,26.8},{-285.8,194.4,-46.0},{-327.6,199.3,-54.4} } },
  { name="FarWall", wall=-1, points={ {51.6,114.4,-39.4},{31.5,147.3,-89.9},{-42.0,157.0,-58.4},{-71.0,165.4,-46.9},{-133.6,186.0,-79.9},{-182.3,203.7,-96.5},{-222.0,211.0,-60.7},{-188.0,204.0,-94.0},{-248.5,222.0,-48.0},{-264.3,233.0,-72.0},{-305.9,234.9,-69.9},{-341.8,229.4,-92.7},{-383.0,236.0,-74.5} } },
}
local BRIDGES = {
  { name="Bridge3", a={42.1,114.4,-12.4}, b={51.6,114.4,-39.4} },
  { name="Bridge", a={-244.5,222.8,50.0}, b={-252.6,220.9,-45.6} },
  { name="Bridge2", a={-435.5,239.6,8.4}, b={-426.1,239.6,-41.3} },
}
local W, STEPH, BARRIER_H, TURN = 8, 1.25, 12, 0.6
local STONE,RISER,TIMBER,GOLD,INK = Color3.fromRGB(150,146,138),Color3.fromRGB(120,116,108),Color3.fromRGB(107,79,51),Color3.fromRGB(212,176,102),Color3.fromRGB(46,48,56)
local rc=RaycastParams.new(); rc.FilterType=Enum.RaycastFilterType.Include; rc.FilterDescendantsInstances={workspace.Terrain}
local function Vp(p) return Vector3.new(p[1],p[2],p[3]) end
local stage=workspace.RoshamboStage
for _,n in {"CanyonPathProto","CanyonPaths"} do local o=stage:FindFirstChild(n); if o then o:Destroy() end end
local root=Instance.new("Folder"); root.Name="CanyonPaths"; root.Parent=stage
local function part(parent,name,size,cf,color,mat,collide,transp)
  local p=Instance.new("Part"); p.Name=name; p.Anchored=true; p.CanCollide=collide; p.CanQuery=false; p.CastShadow=false
  p.Size=size; p.CFrame=cf; p.Color=color; p.Material=mat; p.Transparency=transp or 0; p.Parent=parent; return p
end
local function fit(x,y,z,wall)
  local g=workspace:Raycast(Vector3.new(x,y+6,z),Vector3.new(0,-16,0),rc)
  if g then return Vector3.new(g.Position.X,g.Position.Y,g.Position.Z) end
  if wall~=0 then local d=Vector3.new(0,0,wall); local w=workspace:Raycast(Vector3.new(x,y,z),d*36,rc)
    if w then local o=w.Position-d*(W/2+1); return Vector3.new(o.X,y,o.Z) end end
  return Vector3.new(x,y,z)
end
local function spline(nodes)
  local function nd(i) return nodes[math.clamp(i,1,#nodes)] end
  local function cr(a,b,c,d,t) local t2,t3=t*t,t*t*t
    local function fn(p,q,r,s) return 0.5*((2*q)+(-p+r)*t+(2*p-5*q+4*r-s)*t2+(-p+3*q-3*r+s)*t3) end
    return {fn(a[1],b[1],c[1],d[1]),fn(a[2],b[2],c[2],d[2]),fn(a[3],b[3],c[3],d[3])} end
  local sp={}
  for i=1,#nodes-1 do local p0,p1,p2,p3=nd(i-1),nd(i),nd(i+1),nd(i+2)
    local L=(Vp(p2)-Vp(p1)).Magnitude; local n=math.max(2,math.floor(L/2.2))
    for s=0,n-1 do table.insert(sp,cr(p0,p1,p2,p3,s/n)) end end
  table.insert(sp,nodes[#nodes]); return sp
end
local function lantern(parent,x,y,z)
  part(parent,"Pole",Vector3.new(0.3,6,0.3),CFrame.new(x,y+3,z),INK,Enum.Material.Wood,false)
  local c=part(parent,"Chochin",Vector3.new(1.6,2.2,1.6),CFrame.new(x,y+6,z),GOLD,Enum.Material.Neon,false,0.25)
  local l=Instance.new("PointLight"); l.Brightness=0.9; l.Range=16; l.Color=Color3.fromRGB(255,199,117); l.Parent=c
end
local function buildRoute(route)
  local f=Instance.new("Folder"); f.Name=route.name; f.Parent=root
  local sp=spline(route.points)
  local q={}
  for _,p in sp do local g=fit(p[1],p[2],p[3],route.wall); q[#q+1]={g.X, math.floor(g.Y/STEPH+0.5)*STEPH, g.Z} end
  -- riser cap: subdivide so no step rises > STEPH
  local steps={ q[1] }
  for i=2,#q do
    local a,b=q[i-1],q[i]; local n=math.max(1, math.ceil(math.abs(b[2]-a[2])/STEPH))
    for k=1,n do local t=k/n; steps[#steps+1]={a[1]+(b[1]-a[1])*t, a[2]+(b[2]-a[2])*t, a[3]+(b[3]-a[3])*t} end
  end
  local prevY,acc,nextL=nil,0,22
  for i=1,#steps do
    local p=steps[i]; local a=steps[math.max(1,i-1)]; local b=steps[math.min(#steps,i+1)]
    local dx,dz=b[1]-a[1],b[3]-a[3]; if dx*dx+dz*dz<1e-6 then dx=1 end
    local tgt=Vector3.new(p[1]+dx,p[2],p[3]+dz); local cf=CFrame.lookAt(Vector3.new(p[1],p[2],p[3]),tgt)
    part(f,"Tread"..i,Vector3.new(W,0.6,3.0),cf,STONE,Enum.Material.Slate,true)
    if prevY and p[2]>prevY+0.01 then part(f,"Riser"..i,Vector3.new(W,(p[2]-prevY)+0.6,0.7),CFrame.lookAt(Vector3.new(p[1],(prevY+p[2])/2,p[3]),tgt),RISER,Enum.Material.Slate,true) end
    prevY=p[2]
    local run=math.sqrt(dx*dx+dz*dz); local px,pz=-dz/run,dx/run
    local function gy(s) local h=workspace:Raycast(Vector3.new(p[1]+px*(W/2+2)*s,p[2]+8,p[3]+pz*(W/2+2)*s),Vector3.new(0,-40,0),rc); return h and h.Position.Y or -1e9 end
    local s=(gy(1)<gy(-1)) and 1 or -1
    local ox,oz=px*(W/2)*s, pz*(W/2)*s
    if i%2==1 then part(f,"RailPost"..i,Vector3.new(0.4,3,0.4),CFrame.new(p[1]+ox,p[2]+1.5,p[3]+oz),TIMBER,Enum.Material.Wood,false) end
    part(f,"Barrier"..i,Vector3.new(0.4,BARRIER_H,3.2),cf*CFrame.new(s*(W/2),BARRIER_H/2,0),STONE,Enum.Material.SmoothPlastic,true,1)
    local seg=(i>1) and (Vp(p)-Vp(steps[i-1])).Magnitude or 0; acc+=seg
    if acc>=nextL then lantern(f,p[1]+ox*1.2,p[2],p[3]+oz*1.2); nextL+=22 end
  end
  -- turning platforms at sharp marker nodes
  for i=2,#route.points-1 do
    local g=fit(route.points[i][1],route.points[i][2],route.points[i][3],route.wall)
    local a,b,c=Vp(route.points[i-1]),Vp(route.points[i]),Vp(route.points[i+1])
    local v1=Vector3.new((b-a).X,0,(b-a).Z); local v2=Vector3.new((c-b).X,0,(c-b).Z)
    if v1.Magnitude>1e-3 and v2.Magnitude>1e-3 and math.acos(math.clamp(v1.Unit:Dot(v2.Unit),-1,1))>TURN then
      local ty=math.floor(g.Y/STEPH+0.5)*STEPH
      part(f,"Platform"..i,Vector3.new(W+4,0.6,W+4),CFrame.new(g.X,ty,g.Z),STONE,Enum.Material.Slate,true)
      lantern(f,g.X,ty,g.Z)
    end
  end
end
local function buildBridge(br)
  local f=Instance.new("Folder"); f.Name=br.name; f.Parent=root
  local a,b=Vp(br.a),Vp(br.b); local len=(b-a).Magnitude; if len<1e-3 then return end
  local cf=CFrame.lookAt((a+b)/2,b)
  part(f,"Deck",Vector3.new(6,0.6,len),cf,TIMBER,Enum.Material.WoodPlanks,true)
  for _,sd in {-1,1} do part(f,"BR_Barrier"..sd,Vector3.new(0.4,BARRIER_H,len),cf*CFrame.new(sd*3,BARRIER_H/2,0),TIMBER,Enum.Material.SmoothPlastic,true,1) end
  lantern(f,a.X,a.Y,a.Z); lantern(f,b.X,b.Y,b.Z)
end
for _,r in PATHS do buildRoute(r) end
for _,br in BRIDGES do buildBridge(br) end
return ("built %d routes + %d bridges into RoshamboStage.CanyonPaths"):format(#PATHS,#BRIDGES)
