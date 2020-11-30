using NeuralPDE, Flux, ModelingToolkit, GalacticOptim, Optim, DiffEqFlux
using Plots, PyPlot
using DifferentialEquations, DiffEqBase, DiffEqOperators, LinearAlgebra, OrdinaryDiffEq
using Quadrature, Cubature, Cuba
using Random

Random.seed!(35)

@parameters x y η t θ
@variables u1(..), u2(..), u3(..), u4(..), u5(..), u6(..), u7(..)
@derivatives Dt'~t
@derivatives Dx'~x
@derivatives Dy'~y
@derivatives Dη'~η
@derivatives Dxx''~x
@derivatives Dyy''~y


#functions
u  = u1(x,y,η,t,θ)
v  = u2(x,y,η,t,θ)
w  = u3(x,y,η,t,θ)
ω  = u4(x,y,η,t,θ)
θm = u5(x,y,η,t,θ)
qm = u6(x,y,η,t,θ)
z  = u7(x,y,η,t,θ)

#physical constants
g  = 9.81 #constant or dependent on eta ?
γ  = 1.4 #air cp/cv=1.4
ρd = 1.225 #dry air density
p0 = 101325 #reference pressure 10^5 Pa
Rd = 8.31 #gas constant for dry air
ηc = 0.2 #page 8 of Advanced Research WRF M4

#simulation inputs
sum_of_qs = 0.1 #read from file
#dx =
#dy =
#dz =
Δx = 1 #dummy
Δy = 1 #dummy

#scale factors
dist = x^2 + y^2 #dummy for distance on earth
Dxd  = 2*x #Dx(dist)
Dyd  = 2*y #Dy(dist)
mx   = Δx/dist
my   = Δy/dist

#definitions
αd = 1/ρd
p  = p0*(Rd*θm/(p0*αd))^γ
c1 = 2*ηc*ηc/((1 - ηc)*(1 - ηc)*(1 - ηc))
c2 = -ηc*(4 + ηc + ηc*ηc)/((1 - ηc)*(1 - ηc)*(1 - ηc))
c3 = 2*(1 + ηc + ηc*ηc)/((1 - ηc)*(1 - ηc)*(1 - ηc))
c4 = -(1 + ηc)/((1 - ηc)*(1 - ηc)*(1 - ηc))
B  = c1 + c2*η + c3*η*η + c4*η*η*η
ps = 10 #dummy
pt = 1 #dummy
pd = B*(ps - pt) + (η - B)*(p0 - pt) + pt
μd = (ps - pt)*(c2 + 2*c3*η + 3*c4*η*η) + (p0 - pt)*(1 - c2 - 2*c3*η - 3*c4*η*η) #[μd = Dη(pd)]
D2pd = (ps - pt)*(2*c3 + 6*c4*η) + (p0 - pt)*(-2*c3 - 6*c4*η) # (maybe find η as a function of pd)
#ω  = Dt(η)
U  = μd*u/my
V  = μd*v/mx
W  = μd*w/my
Ω  = μd*ω/my
Θm = μd*θm
Qm = μd*qm
ϕ  = g*z
α  = αd/(1 + sum_of_qs)


#divergences
#divVu  = Dx(U*u)  + Dy(V*u)  + Dη(Ω*u)
#divVv  = Dx(U*v)  + Dy(V*v)  + Dη(Ω*v)
#divVw  = Dx(U*w)  + Dy(V*w)  + Dη(Ω*w)
#divVθm = Dx(U*θm) + Dy(V*θm) + Dη(Ω*θm)
#divV   = Dx(V)    + Dy(V)    + Dη(V)
#divVqm = Dx(U*qm) + Dy(V*qm) + Dη(Ω*qm)
divVu1 = μd*u/Δy*(u*Dxd + 2*dist*Dx(u))
divVu2 = μd/Δx*(u*v*Dyd + dist*u*Dy(v) + dist*v*Dy(u))
divVu3 = dist/Δy*(D2pd*u*ω + μd*Dη(u)*ω + μd*u*Dη(ω))
divVu  = divVu1 + divVu2 + divVu3


divVv1 = μd/Δy*(u*v*Dxd + dist*u*Dx(v) + dist*v*Dx(u))
divVv2 = μd/Δx*(v*v*Dyd + dist*2*v*Dy(v))
divVv3 = 1/my*(D2pd*w*v + μd*Dη(ω)*v + μd*ω*Dη(v))
divVv  = divVv1 + divVv2 + divVv3

divVw1 = μd/Δy*(Dxd*u*w + dist*Dx(u)*w + dist*u*Dx(w))
divVw2 = μd/Δx*(Dyd*v*w + dist*Dy(v)*w + dist*v*Dy(w))
divVw3 = 1/my*(D2pd*ω*w + μd*Dη(ω)*w   + μd*ω*Dη(w))
divVw  = divVw1 + divVw2 + divVw3


divVθm1 = μd/Δy*(Dxd*u*θm + dist*Dx(u)*θm + dist*u*Dx(θm))
divVθm2 = μd/Δx*(Dyd*v*θm + dist*Dy(v)*θm + dist*v*Dy(θm))
divVθm3 = 1/my*(D2pd*ω*θm + μd*Dη(ω)*θm   + μd*ω*Dη(θm))
divVθm  = divVθm1 + divVθm2 + divVθm3

divV1 = μd/Δx*(Dxd*v + dist*Dx(v))
divV2 = μd/Δx*(Dyd*v + dist*Dy(v))
divV3 = 1/mx*(D2pd*v + μd*Dη(v))
divV  = divV1 + divV2 + divV3

divVqm1 = μd/Δy*(Dxd*u*qm + dist*Dx(u)*qm + dist*u*Dx(qm))
divVqm2 = μd/Δx*(Dyd*v*qm + dist*Dy(v)*qm + dist*v*Dy(qm))
divVqm3 = 1/my*(D2pd*ω*qm + μd*Dη(ω)*qm   + μd*ω*Dη(qm))
divVqm  = divVqm1 +divVqm2 + divVqm3

#inner products
innerV∇ϕ = U*g*Dx(z) + V*g*Dy(z) + Ω*g*Dη(z) #U*Dx(ϕ) + V*Dy(ϕ) + Ω*Dη(ϕ)


#geographic parametrization
Ωe = 0.0000727 #dummy #angular rotation rate of earth
ψ  = 1 #dummy #latitude on earth
re = 6371 #dummy #radius of earth
αr = 1 #dummy #local rotation angle between y-axis and the meridians

f  = 2*Ωe*sin(ψ)
e  = 2*Ωe*cos(ψ)

#external forcings
Dymx = -Δx/(dist*dist)*Dyd
Dxmy = -Δy/(dist*dist)*Dxd

FU  =  (mx/my)*(f + u*(my/mx)*Dymx - v*Dxmy)*V - (u/re + e*cos(αr))*W
FV  = -(my/mx)*((f + u*(my/mx)*Dymx - v*Dxmy*U + (v/re - e*sin(αr))*W))
FW  = e*(U*cos(αr) - (mx/my)*V*sin(αr) + 1/re*(u*U + (mx/my)*v*V))
FΘm = 0 #dummy
FQm = 0 #dummy


#equations (Flux-Form Euler)
#eq1 = Dt(U) + divVu + μd*α*Dx(p) + (α/αd)*Dη(p)*Dx(ϕ) ~ FU
#eq2 = Dt(V) + divVv + μd*α*Dy(p) + (α/αd)*Dη(p)*Dy(ϕ) ~ FV
#eq3 = Dt(W) + divVw - g*((α/αd)*Dη(p) - μd)           ~ FW
#eq4 = Dt(Θm) + divVθm                                 ~ FΘm
#eq5 = Dt(μd) + divV                                   ~ 0
#eq6 = Dt(ϕ)  + (1/μd)*(innerV∇ϕ - g*W)                ~ 0
#eq7 = Dt(Qm) + divVqm                                 ~ FQm

eq1 = μd/my*Dt(u) + divVu + μd*α*p0*(Rd/(p0*αd))^γ*γ*θm^(γ-1)*Dx(θm) + (α/αd)*p0*(Rd/(p0*αd))^γ*γ*θm^(γ-1)*Dη(θm)*g*Dx(z) ~ FU
eq2 = μd/mx*Dt(v) + divVv + μd*α*p0*(Rd/(p0*αd))^γ*γ*θm^(γ-1)*Dy(θm) + (α/αd)*p0*(Rd/(p0*αd))^γ*γ*θm^(γ-1)*Dη(θm)*g*Dy(z) ~ FV
eq3 = μd/my*Dt(w) + divVw - g*((α/αd)*p0*(Rd/(p0*αd))^γ*γ*θm^(γ-1)*Dη(θm) - μd)                                           ~ FW


eq4 = μd*Dt(θm) + divVθm                   ~ FΘm #coupling with SFIRE
eq5 = divV                                 ~ 0.
eq6 = g*Dt(z)  + (1.0/μd)*(innerV∇ϕ - g*W) ~ 0.
eq7 = μd*Dt(qm) + divVqm                   ~ FQm  #coupling with SFIRE

#system of equations
eqs = [eq1,eq2,eq3,eq4,eq5,eq6,eq7]

# Initial and boundary conditions
x0 = 0.5
y0 = 0.5
η0 = 0.5

bcs =    [u1(x,y,η,0,θ) ~ (x - x0)^2 + (y - y0)^2 + (η - η0)^2,
          u2(x,y,η,0,θ) ~ (x - x0)^2 + (y - y0)^2 + (η - η0)^2,
          u3(x,y,η,0,θ) ~ (x - x0)^2 + (y - y0)^2 + (η - η0)^2,
          u4(x,y,η,0,θ) ~ (x - x0)^2 + (y - y0)^2 + (η - η0)^2,
          u5(x,y,η,0,θ) ~ (x - x0)^2 + (y - y0)^2 + (η - η0)^2,
          u6(x,y,η,0,θ) ~ (x - x0)^2 + (y - y0)^2 + (η - η0)^2,
          u7(x,y,η,0,θ) ~ (x - x0)^2 + (y - y0)^2 + (η - η0)^2]

#=
k = 0.4
u0 = 0.5
z0 = 0.5


bcs = [u1(x,y,η,0,θ) ~ u0/k*log(z/z0),
       u2(x,y,η,0,θ) ~ 0.,
       u3(x,y,η,0,θ) ~ 0.,
       u4(x,y,η,0,θ) ~ 0.,
       u5(x,y,η,0,θ) ~ 320,
       u6(x,y,η,0,θ) ~ 1.,
       u7(x,y,η,0,θ) ~ 10.] # physically meaningful bcs
=#

# Space and time domains
domains = [x ∈ IntervalDomain(0.0,1.0),
           y ∈ IntervalDomain(0.0,1.0),
           η ∈ IntervalDomain(0.0,1.0),
           t ∈ IntervalDomain(0.0,1.0)]# Discretization

# Discretization
dx = 0.1; dy= 0.1; dη = 0.1; dt = 0.1

# Neural network
input_ = length(domains)
output = length(eqs)

n      = 16
chain = FastChain(FastDense(input_,n,Flux.σ),FastDense(n,n,Flux.σ),FastDense(n,n,Flux.σ),FastDense(n,n,Flux.σ),FastDense(n,output)) 


q_strategy = NeuralPDE.QuadratureTraining(algorithm =CubaCuhre(),reltol=1e-8,abstol=1e-8,maxiters=150)
discretization = NeuralPDE.PhysicsInformedNN([dx,dy,dη,dt],chain,strategy = q_strategy)

#discretization = NeuralPDE.PhysicsInformedNN([dx,dy,dη,dt],
#                                             chain,
#                                             strategy = NeuralPDE.StochasticTraining())
pde_system = PDESystem(eqs,bcs,domains,[x,y,η,t],[u1,u2,u3,u4,u5,u6,u7])
prob = NeuralPDE.discretize(pde_system,discretization)

#NumDiscretization = MOLFiniteDifference(0.1)
#numProb = DiffEqBase.discretize(pde_system, NumDiscretization)

#Remember to clearly explain in D3 that in levelset equation we compare
#  WRF out with NeuralPDE out, while in this system we compare the NeuralPDE
#  with a numerical result that uses the same numerical solver (RK3) of WRF
#  but the calculation is done in Julia. Remember to specify that this is a
#  feasibility study.

#numSol = DifferentialEquations.solve(numProb, RK4(), reltol=1e-5,abstol=1e-5)

listTraining = [0.0]

cb = function (p,l)
    println("Current loss is: $l")
    append!(listTraining,l)
    return false
end

res = GalacticOptim.solve(prob, ADAM(0.01), cb = cb, maxiters=30)
initθ = res.minimizer

discretization2 = NeuralPDE.PhysicsInformedNN([dx,dy,dη,dt],chain, initθ; strategy = q_strategy)
initθ == discretization2.initθ
prob2 = NeuralPDE.discretize(pde_system,discretization2)
res2 = GalacticOptim.solve(prob2, ADAM(0.01), cb = cb, maxiters=1000)
#res2 = GalacticOptim.solve(prob, p = res.minimizer,  ADAM(0.01), cb=cb, maxiters=10)
phi = discretization.phi

#strategy = StochasticTraining()
#discretization = PhysicsInformedNN([dx,dy,dη, dt],chain,strategy=strategy)

#=
indvars = [x,y,η,t]
depvars = [u1,u2,u3,u4,u5,u6,u7]


dim = length(domains)

expr_pde_loss_function = build_loss_function(eqs,indvars,depvars)
expr_bc_loss_functions = [build_loss_function(bc,indvars,depvars) for bc in bcs]
train_sets = generate_training_sets(domains,[dx,dy,dη,dt],bcs,indvars,depvars)

train_domain_set, train_bound_set, train_set = train_sets

phi = discretization.phi
autodiff = discretization.autodiff
derivative = discretization.derivative
initθ = discretization.initθ

pde_loss_function = get_loss_function(eval(expr_pde_loss_function),
                                      train_domain_set,
                                      phi,
                                      derivative,
                                      strategy)
bc_loss_function = get_loss_function(eval.(expr_bc_loss_functions),
                                     train_bound_set,
                                     phi,
                                     derivative,
                                     strategy)


function loss_function(θ,p)
    return pde_loss_function(θ) + bc_loss_function(θ)
end

cb = function (p,l)
    println("Current loss is: $l")
    return false
end

f = NeuralPDE.OptimizationFunction(loss_function, GalacticOptim.AutoZygote())

prob = GalacticOptim.OptimizationProblem(f, initθ)

# optimizer
opt = GalacticOptim.ADAM(0.01)
res = GalacticOptim.solve(prob, opt; cb = cb, maxiters=2)
phi = discretization.phi
=#

xs,ys,ηs,ts = [domain.domain.lower:dx:domain.domain.upper for (dx,domain) in zip([dx,dy,dη,dt],domains)]

#u_predict = [reshape([first(phi([x,y,η,t],res.minimizer)) for x in xs  for y in ys for η in ηs], (length(xs),length(ys),length(ηs)))  for t in ts ]

u_predict  = [reshape([phi([x,y,η,t],res2.minimizer)[i] for x in xs for y in ys for η in ηs for t in ts],
              (length(xs),length(ys),length(ηs),length(ts))) for i in 1:7]

u_predict

Plots.plot(listTraining[3:end], yaxis=:log, ylabel="Loss function", xlabel="Epochs (ADAM)", legend=false, title="Training")
Plots.savefig("euler_training_test_2.pdf")


ic(x,y) = (x - x0)^2 + (y - y0)^2
initial_cond = reshape([ic(x,y) for x in xs for y in ys], (length(xs),length(ys)))
Plots.plot(xs, ys, u_predict[1][:,:,1,1], st=:surface)
Plots.plot(xs, ys, initial_cond, st=:surface)


#------------------TRAINING TESTS WITH PARABOLIC BCS---------------

#-------TEST 1 ---------------
#Training started at 13:25 - ADAM(0.022) - 3.500 iterations
#Training finished at 15:02 loss 10^7 => 545.79
#

#------TEST 2------------------
#Training started at 13:11 - ADAM(0.02) - 2.200 iterations
#Training finished at  loss 7.6*10^7 =>
#NN with 2 hidden layers (16 neurons)
#QuadratureTraining with reltol and abstol = 1e-8 , maxiters = 150