# playing with automatic differentiation. see:
# https://www.juliabloggers.com/automatic-differentiation-with-dual-numbers/
# https://juliadiff.org/
#
using DifferentiationInterface
using ForwardDiff
using Zygote, FiniteDifferences

"""
functor, I think
"""
function f(y)
    function g(x)
       if x > 4
          x^2 + y
       else
          x^2
       end
    end
    return g
end

# operator overloading backend
ForwardDiff.derivative(h,4.00000)
# Source transformation AD backend
DifferentiationInterface.derivative(h,AutoZygote(),4)
# numeric backend
DifferentiationInterface.derivative(h,AutoFiniteDifferences(fdm=FiniteDifferences.FiniteDifferenceMethod([1,2],1;)),4-0.000001)



