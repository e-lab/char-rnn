-- E. Culurciello
-- June 2015
--
-- tatoeba translation sentences parser:
-- http://tatoeba.org/eng/downloads

-- desired parameters:
lang1 = 'ita' -- translate from
lang2 = 'eng' -- translate to
n_pairs = 500000 -- sentence pairs wanted
s_pairs = {} -- table of sentences

if not (path.exists('links.csv') or path.exists('sentences.csv')) then
   print('Download Sentences and Links files from: http://tatoeba.org/eng/downloads and unzip to *.csv files')
end

function readLinks(filepath)
   local file = io.open(filepath,'r')
   local data = {}
   while 1 do
      local col = {}
      fline = file:read()
      if fline == nil then break end
      for word in fline:gmatch("%d+") do
         table.insert(col, tonumber(word))
      end
      table.insert(data, col)
   end
   file:close()
   return data
end


function readSentences(filepath)
   local file = io.open(filepath,'r')
   local data = {}
   i=1
   while i<50 do
      i=i+1
      fline = file:read()
      if fline == nil then break end
      numbline, language, sentence = string.match(fline, "(%d+)\t(%a+)\t(.+)")
      table.insert(data, tonumber(numbline), {language, sentence})
      -- print({numbline, language, sentence})
   end
   file:close()
   return data
end


function grabSentences(filepath, d_language1, d_language2)
   local file = io.open(filepath,'r')
   local data = {}
   local count1 = 0
   local count2 = 0
   while 1 do
      fline = file:read()
      if fline == nil then break end
      
      numbline, language, sentence = string.match(fline, "(%d+)\t(%a+)\t(.+)")
      
      if language == d_language1 then
         count1 = count1 + 1
         table.insert(data, numbline, {language, sentence})
      end
      
      if language == d_language2 then
         count2 = count2 + 1
         table.insert(data, numbline, {language, sentence})
      end

   end
   file:close()
   print('we grabbed ', count1, lang1, ' and ',count2, lang2)
   return data
end


print('loading links file...')
links = readLinks('links.csv')
print('Number of translated sentences [links]:', #links)


-- generic loading of ALL sentences:
-- print('loading sentences file...')
-- sentences = readSentences('sentences.csv')
-- print('Number of sentences:', #sentences)
-- for i=1,100 do print(sentences[i]) end



-- Load two specific languages for translation:
sentences = grabSentences('sentences.csv', lang1, lang2, n_pairs)
print('Number of sentences:', #sentences)
-- for i = 1, n_pairs,100 do
--    print(sentences[i])
-- end
-- print(sentences)


-- create translation sentences pairs:
itx = 1
count = 1
while count < n_pairs and itx <= #links do
   if sentences[links[itx][1]] and sentences[links[itx][2]] then -- if links exist:
      if sentences[links[itx][1]][1] == lang1 and sentences[links[itx][2]][1] == lang2 then
         -- print('\nPair number:', count, '\n', sentences[links[itx][1]], sentences[links[itx][2]])
         table.insert(s_pairs, {sentences[links[itx][1]], sentences[links[itx][2]]})
         count = count + 1
      end
   end
   itx = itx+1
   if itx % 1e6 == 0 then collectgarbage() print(itx) end
end

-- save torch fil, just in case:
torch.save('sentence_pairs.t7', s_pairs)


-- save text file of sentence and translation concatenated:
pf,err = io.open("input.txt","w")
-- line by line:
for i, pair in ipairs(s_pairs) do
   if pair == nil then break end
   pf:write(pair[1][2] .. '|' .. pair[2][2] .. '|\n') -- "|" is the "end of sentence" character
 end
pf:close()




