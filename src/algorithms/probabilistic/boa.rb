# Bayesian Optimization Algorithm in the Ruby Programming Language

# The Clever Algorithms Project: http://www.CleverAlgorithms.com
# (c) Copyright 2010 Jason Brownlee. Some Rights Reserved. 
# This work is licensed under a Creative Commons Attribution-Noncommercial-Share Alike 2.5 Australia License.

def onemax(vector)
  return vector.inject(0){|sum, value| sum + value}
end

def random_bitstring(size)
  return Array.new(size){ ((rand()<0.5) ? 1 : 0) }
end

def binary_tournament(pop)
  i, j = rand(pop.size), rand(pop.size)
  j = rand(pop.size) while i==j
  return (pop[i][:cost] > pop[j][:cost]) ? pop[i] : pop[j]
end

def path_exists?(i, j, graph)
  visited, stack = [], [i]
  while !stack.empty?
    return true if stack.include?(j)
    k = stack.shift
    next if visited.include?(k)
    visited << k
    graph[k][:out].each {|m| stack.unshift(m) if !visited.include?(m)}    
  end
  return false
end

def can_add_edge?(i, j, graph)
  return !graph[i][:out].include?(j) && !path_exists?(j, i, graph)
end

def get_viable_parents(node, graph)
  viable = []
  graph.size.times do |i|
    if node!=i and can_add_edge?(node, i, graph)
      viable << i
    end
  end
  return viable
end

def compute_count_for_edges(pop, indexes)
  counts = Array.new(2**(indexes.size)){0}
  pop.each do |p|
    index = 0
    indexes.reverse.each_with_index do |v,i|
      index += ((p[:bitstring][v] == 1) ? 1 : 0) * (2**i)
    end
    counts[index] += 1
  end
 return counts
end

def fact(v)
  return v <= 1 ? 1 : v*fact(v-1)
end

def k2equation(node, candidates, pop)
  counts = compute_count_for_edges(pop, [node]+candidates)
  total = nil
  (counts.size/2).times do |i|
    a1, a2 = counts[i*2], counts[(i*2)+1]
    rs = (1.0/fact((a1+a2)+1).to_f) * fact(a1).to_f * fact(a2).to_f
    total = (total.nil? ? rs : total*rs)
  end
  return total
end

def compute_gains(node, graph, pop)
  viable = get_viable_parents(node[:num], graph)
  gains = Array.new(graph.size) {-1}
  gains.each_index do |i|
    if viable.include?(i)
      gains[i] = k2equation(node[:num], node[:in]+[i], pop)
    end
  end  
  return gains
end

def construct_network(pop, prob_size, max_edges=5*pop.size)
  graph = Array.new(prob_size) {|i| {:out=>[], :in=>[], :num=>i} }
  gains = Array.new(prob_size)  
  max_edges.times do
    max, from, to = -1, nil, nil
    graph.each_with_index do |node, i|
      gains[i] = compute_gains(node, graph, pop)
      gains[i].each_with_index {|v,j| from,to,max = i,j,v if v>max}
    end
    break if max <= 0.0
    graph[from][:out] << to
    graph[to][:in] << from
  end
  return graph
end

def topological_ordering(graph)
  # lazy, make sure root nodes are first
  # this does no not ensure that all parents will have a value 
  return graph.sort{|x,y| x[:in].size<=>y[:in].size}  
  # TODO
end

def marginal_probability(i, pop)
  return pop.inject(0.0){|s,x| s + x[:bitstring][i]} / pop.size.to_f
end

def calculate_probability(node, bitstring, graph, pop)
  return marginal_probability(node[:num], pop) if node[:in].empty?
  counts = compute_count_for_edges(pop, [node[:num]]+node[:in])
  index = 0
  node[:in].reverse.each_with_index do |v,i|
    index += ((bitstring[v] == 1) ? 1 : 0) * (2**i)
  end  
  i1 = index + (1*2**(node[:in].size))
  i2 = index + (0*2**(node[:in].size)) 
  a1, a2 = counts[i1].to_f, counts[i2].to_f
  return a1/(a1+a2)
end

def probabilistic_logic_sample(graph, pop)
  bitstring = Array.new(graph.size)
  graph.each do |node|
    prob = calculate_probability(node, bitstring, graph, pop)
    bitstring[node[:num]] = ((rand() < prob) ? 1 : 0)
  end
  return {:bitstring=>bitstring}
end

def sample_from_network(pop, graph, num_samples)
  ordered = topological_ordering(graph)  
  samples = Array.new(num_samples) do
    probabilistic_logic_sample(graph, pop)
  end
  return samples
end

def search(num_bits, max_iter, pop_size, select_size)
  pop = Array.new(pop_size) { {:bitstring=>random_bitstring(num_bits)} }
  pop.each{|c| c[:cost] = onemax(c[:bitstring])}
  best = pop.sort{|x,y| y[:cost] <=> x[:cost]}.first
  max_iter.times do |it|
    selected = Array.new(select_size) { binary_tournament(pop) }
    network = construct_network(selected, num_bits)
    arcs = network.inject(0){|s,x| s+x[:out].size}
    samples = sample_from_network(selected, network, pop_size)
    samples.each{|c| c[:cost] = onemax(c[:bitstring])}
    pop = (samples+pop).sort{|x,y| y[:cost]<=>x[:cost]}.first(pop_size)
    best = pop.first if pop.first[:cost] > best[:cost]
    puts " >it=#{it}, arcs=#{arcs}, f=#{best[:cost]}, [#{best[:bitstring]}]"
    break if best[:cost]==num_bits
  end
  return best
end

if __FILE__ == $0
  # problem configuration
  num_bits = 20
  # algorithm configuration
  max_iter = 40
  pop_size = 50
  select_size = 10
  # execute the algorithm
  best = search(num_bits, max_iter, pop_size, select_size)
  puts "done! Solution: f=#{best[:cost]}/#{num_bits}, s=#{best[:bitstring]}"
end