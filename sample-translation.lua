
--[[

This file samples characters from a trained model

Code is based on implementation in 
https://github.com/oxford-cs-ml-2015/practical6

]]--

require 'torch'
require 'nn'
require 'nngraph'
require 'optim'
require 'lfs'

require 'util.OneHot'
require 'util.misc'

cmd = torch.CmdLine()
cmd:text()
cmd:text('Sample from a character-level language model')
cmd:text()
cmd:text('Options')
-- required:
cmd:argument('-model','model checkpoint to use for sampling')
-- optional parameters
cmd:option('-data_dir','data/translation','data directory. Should contain the file input.txt with input data')
cmd:option('-seed',123,'random number generator\'s seed')
cmd:option('-sample',1,' 0 to use max at each timestep, 1 to sample at each timestep')
cmd:option('-primetext'," ",'used as a prompt to "seed" the state of the LSTM using a given sequence, before we sample.')
cmd:option('-number',10,'number of sentences to test')
cmd:option('-length',25,'number of characters to sample')
cmd:option('-temperature',1,'temperature of sampling')
cmd:option('-gpuid',0,'which gpu to use. -1 = use CPU')
cmd:text()

local pf = function(...) print(string.format(...)) end
local Cr = sys.COLORS.red
local Cb = sys.COLORS.blue
local Cg = sys.COLORS.green
local Cn = sys.COLORS.none

-- parse input params
opt = cmd:parse(arg)

if opt.gpuid >= 0 then
    print('using CUDA on GPU ' .. opt.gpuid .. '...')
    require 'cunn'
    require 'cutorch'
    cutorch.setDevice(opt.gpuid + 1) -- note +1 to make it 0 indexed! sigh lua
end
torch.manualSeed(opt.seed)

-- load the model checkpoint
if not lfs.attributes(opt.model, 'mode') then
    print('Error: File ' .. opt.model .. ' does not exist. Are you sure you didn\'t forget to prepend cv/ ?')
end
checkpoint = torch.load(opt.model)
protos = checkpoint.protos

-- initialize the vocabulary (and its inverted version)
local vocab = checkpoint.vocab
local ivocab = {}
for c,i in pairs(vocab) do ivocab[i] = c end

-- initialize the rnn state
local current_state
local model = checkpoint.opt.model

print('creating an LSTM...')
local num_layers = checkpoint.opt.num_layers
current_state = {}
for L=1,checkpoint.opt.num_layers do
    -- c and h for all layers
    local h_init = torch.zeros(1, checkpoint.opt.rnn_size)
    if opt.gpuid >= 0 then h_init = h_init:cuda() end
    table.insert(current_state, h_init:clone())
    table.insert(current_state, h_init:clone())
end
local state_size = #current_state

protos.rnn:evaluate() -- put in eval mode so that dropout works properly

-- load sentences to test:
local seed_text = {}
local input_file = path.join(opt.data_dir, 'input.txt')
print('Loading input sentences file: ' .. input_file)
local s_file = io.open(input_file,'r')
for i=1, opt.number do
  fline = s_file:read()
  sentence = string.match(fline, "[^.]+%p<") -- stop at: '%punctuation' and '<'
  table.insert(seed_text, sentence)
end
s_file:close()


-- for every sentence in test set:
for j=1, opt.number do
    -- do a few seeded timesteps
    pf(Cr .. '\n\nseeding with:\n"' ..Cb .. seed_text[j] ..'"' .. Cn)
    for c in seed_text[j]:gmatch'.' do
        prev_char = torch.Tensor{vocab[c]}
        if opt.gpuid >= 0 then prev_char = prev_char:cuda() end
        local lst = protos.rnn:forward{prev_char, unpack(current_state)}
        -- lst is a list of [state1,state2,..stateN,output]. We want everything but last piece
        current_state = {}
        for i=1,state_size do table.insert(current_state, lst[i]) end
        prediction = lst[#lst] -- last element holds the log probabilities
    end

-- start sampling/argmaxing
    for i=1, opt.length do

        -- log probabilities from the previous timestep
        if opt.sample == 0 then
            -- use argmax
            local _, prev_char_ = prediction:max(2)
            prev_char = prev_char_:resize(1)
        else
            -- use sampling
            prediction:div(opt.temperature) -- scale by temperature
            local probs = torch.exp(prediction):squeeze()
            probs:div(torch.sum(probs)) -- renormalize so probs sum to one
            prev_char = torch.multinomial(probs:float(), 1):resize(1):float()
        end

        -- forward the rnn for next character
        local lst = protos.rnn:forward{prev_char, unpack(current_state)}
        current_state = {}
        for i=1,state_size do table.insert(current_state, lst[i]) end
        prediction = lst[#lst] -- last element holds the log probabilities

        io.write(ivocab[prev_char[1]])
    end
end
io.write('\n') io.flush()

