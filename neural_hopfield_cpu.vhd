------------------------------------------------------------------
--Copyright 2023 Andrey S. Ionisyan (anserion@gmail.com)
--Licensed under the Apache License, Version 2.0 (the "License");
--you may not use this file except in compliance with the License.
--You may obtain a copy of the License at
--    http://www.apache.org/licenses/LICENSE-2.0
--Unless required by applicable law or agreed to in writing, software
--distributed under the License is distributed on an "AS IS" BASIS,
--WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
--See the License for the specific language governing permissions and
--limitations under the License.
------------------------------------------------------------------

----------------------------------------------------------------------------------
-- Engineer: Andrey S. Ionisyan <anserion@gmail.com>
-- 
-- Description: Hopfield neural network CPU
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use ieee.std_logic_signed.all;

entity neural_hopfield_cpu is
   generic (N:natural range 1 to 16:=8);
    Port ( 
		clk       : in std_logic;
      reset     : in std_logic;
      reload    : in std_logic;
      learn     : in std_logic;
      forget    : in std_logic;
      data_in_addr: in std_logic_vector(N-1 downto 0);
      data_in  : in std_logic_vector(7 downto 0);
      data_out_addr: in std_logic_vector(N-1 downto 0);
      data_out : out std_logic_vector(7 downto 0);
      trained   : out std_logic
	 );
end neural_hopfield_cpu;

architecture XC7K325T of neural_hopfield_cpu is
constant W_WIDTH:natural range 1 to 64:=8;

component rnd16_module is
    Generic (seed:STD_LOGIC_VECTOR(31 downto 0));
    Port ( 
      clk: in  STD_LOGIC;
      rnd16: out STD_LOGIC_VECTOR(15 downto 0)
	 );
end component;

COMPONENT RAM_2NxM_2in_2out is
    generic (N:natural range 1 to 20:=0; M:natural range 1 to 32:=8);
    port (CLK  : in std_logic;
          WEA  : in std_logic_vector(0 downto 0);
          WEB  : in std_logic_vector(0 downto 0);
          ADDRA: in std_logic_vector(N-1 downto 0);
          DINA : in std_logic_vector(M-1 downto 0);
          DOUTA: out std_logic_vector(M-1 downto 0);
          ADDRB: in std_logic_vector(N-1 downto 0);
          DINB : in std_logic_vector(M-1 downto 0);
          DOUTB: out std_logic_vector(M-1 downto 0)
    );
end COMPONENT;

component RAM_2NxM is
    generic (N:natural range 1 to 32:=1; M:natural range 1 to 32:=8);
    port (CLKA : in std_logic;
          WEA  : in std_logic_vector(0 downto 0);
          ADDRA: in std_logic_vector(N-1 downto 0);
          DINA : in std_logic_vector(M-1 downto 0);
          ADDRB: in std_logic_vector(N-1 downto 0);
          DOUTB: out std_logic_vector(M-1 downto 0)
    );
end component;

signal rnd16: std_logic_vector(15 downto 0);

signal data_inout_addr: std_logic_vector(N-1 downto 0) := (others=>'0');
signal data_in_reg: std_logic_vector(7 downto 0) := (others=>'0');
signal data_out_reg: std_logic_vector(7 downto 0) := (others=>'0');

signal data_addr: std_logic_vector(N-1 downto 0) := (others=>'0');
signal data_rd_value: std_logic_vector(7 downto 0) := (others=>'0');
signal data_wr_value: std_logic_vector(7 downto 0) := (others=>'0');
signal data_ready: std_logic := '0';

signal w_cwr: std_logic := '0';
signal w_rd_addr: std_logic_vector(2*N-1 downto 0) := (others=>'0');
signal w_rd_value: std_logic_vector(W_WIDTH-1 downto 0) := (others=>'0');
signal w_wr_addr: std_logic_vector(2*N-1 downto 0) := (others=>'0');
signal w_wr_value: std_logic_vector(W_WIDTH-1 downto 0) := (others=>'0');

begin
rnd16_chip: rnd16_module
   generic map (conv_std_logic_vector(26535,32))
	port map(clk,rnd16);

pixels_RAM : RAM_2NxM_2in_2out
  GENERIC MAP(N,8)
  PORT MAP (
    clk  => clk,
    wea  => (0=>reload),
    addra=> data_inout_addr,
    dina => data_in_reg,
    douta=> data_out_reg,
    web  => (0=>data_ready),
    addrb=> data_addr,
    dinb => data_wr_value,
    doutb=> data_rd_value
  );

process(clk)
begin
   if rising_edge(clk) then
      if reload='1'
      then data_inout_addr <= data_in_addr;
      else data_inout_addr <= data_out_addr;
      end if;
      data_in_reg<=data_in;
      data_out<=data_out_reg;
   end if;
end process;

W_RAM : RAM_2NxM
  GENERIC MAP(2*N,W_WIDTH)
  PORT MAP (clk, (0=>w_cwr), w_wr_addr, w_wr_value, w_rd_addr, w_rd_value);

process(clk)
variable fsm: natural range 0 to 63:=0;
variable scalar: integer:=0;
variable A_addr:std_logic_vector(N-1 downto 0):=(others=>'0');
variable pattern_i:integer:=0;
variable pattern_j:integer:=0;
variable reset_latch:std_logic:='0';
variable reload_latch:std_logic:='0';
variable cnt:natural:=0;
begin
if rising_edge(clk) then
   if (reset='1')and(reset_latch='0') then fsm:=0; end if;
   if (reload='1')and(reload_latch='0') then fsm:=4; end if;
   case fsm is
      ----------------------------------
      -- init W
      ----------------------------------
      --  for k:=0 to N-1 do
      --    for i:=0 to N-1 do
      --      W[k,i]:=0;
      when 0=> reset_latch:='1'; reload_latch:='1'; 
               W_wr_addr<=(others=>'0');
               W_wr_value<=(others=>'0');
               W_cwr<='1';
               fsm:=1;
      when 1=> if W_wr_addr=(2*N-1 downto 0 =>'1')
               then fsm:=2;
               else W_wr_addr<=W_wr_addr+1; fsm:=1;
               end if; 
      when 2=> if reset='0' then
                  W_cwr<='0';
                  reset_latch:='0';
                  reload_latch:='0';
                  trained<='1';
                  fsm:=8;
               end if;

      ------------------------------------
      -- Hopfield ordinary step
      ------------------------------------
      --  while (true) do
      --  begin
      --    A:=random(N);
      --    scalar:=0;
      --    for i:=0 to N-1 do
      --       if data[i]>=128 then scalar:=scalar+W[A,i]
      --                       else scalar:=scalar-W[A,i];
      --    if scalar>=0 then data[A]:=255 else data[A]:=0;
      --  end;
      when 4=> reload_latch:='1'; trained<='0'; fsm:=5;
      when 5=> if reload='0' then fsm:=6; end if;
      when 6=> if learn='1' then cnt:=0; fsm:=16; else fsm:=7; end if;
      when 7=> if forget='1' then cnt:=0; fsm:=32; else fsm:=8; end if;

      when 8=> reload_latch:='0'; trained<='1';
               A_addr:=rnd16(N-1 downto 0);
               data_addr<=(others=>'0');
               fsm:=9;
      when 9=> W_rd_addr<=A_addr & (N-1 downto 0 => '0');
               scalar:=0; fsm:=10;
      when 10=>if conv_integer("0"&data_rd_value)>=128
               then scalar:=scalar+conv_integer(W_rd_value);
               else scalar:=scalar-conv_integer(W_rd_value);
               end if;
               fsm:=11;
      when 11=>if data_addr=(N-1 downto 0 =>'1')
               then
                  if scalar>0
                  then data_wr_value<=(others=>'1');
                  else data_wr_value<=(others=>'0');
                  end if;
                  fsm:=12;
               else
                  W_rd_addr<=W_rd_addr+1;
                  data_addr<=data_addr+1;
                  fsm:=10;
               end if;
      when 12=>data_addr<=A_addr;
               data_ready<='1';
               fsm:=13;
      when 13=>data_ready<='0'; fsm:=8;

      ----------------------------------
      -- Hopfield learn algorithm
      ----------------------------------
      --  for i:=1 to 2**N do
      --    for j:=1 to 2**N do
      --        if i<>j then
      --          if (Pattern[i]=1 and Pattern[j]=1) or
      --             (Pattern[i]=-1 and Pattern[j]=-1)
      --          then W[i,j]:=W[i,j]+1
      --          else W[i,j]:=W[i,j]-1;
      when 16=>trained<='0'; reload_latch:='1';
               if cnt=2**18 then fsm:=17; else cnt:=cnt+1; end if;
      when 17=>W_rd_addr<=(others => '0');
               W_wr_addr<=(others => '0');
               fsm:=18;
      when 18=>if W_rd_addr(N-1 downto 0) = W_rd_addr(2*N-1 downto N)
               then fsm:=25; else fsm:=19;
               end if;
      when 19=>data_addr<=W_rd_addr(2*N-1 downto N); fsm:=20;
      when 20=>if conv_integer("0"&data_rd_value)<128 then pattern_i:=-1; else pattern_i:=1; end if;
               fsm:=21;
      when 21=>data_addr<=W_rd_addr(N-1 downto 0); fsm:=22;
      when 22=>if conv_integer("0"&data_rd_value)<128 then pattern_j:=-1; else pattern_j:=1; end if;
               fsm:=23;
      when 23=>
               if ((pattern_i=1)and(pattern_j=1))or((pattern_i=-1)and(pattern_j=-1))
               then W_wr_value<=W_rd_value+1;
               else W_wr_value<=W_rd_value-1;
               end if;
               w_cwr<='1'; fsm:=24;
      when 24=>w_cwr<='0'; fsm:=25;
      when 25=>if W_rd_addr=(2*N-1 downto 0 =>'1')
               then fsm:=26;
               else W_rd_addr<=W_rd_addr+1; W_wr_addr<=W_wr_addr+1; fsm:=18;
               end if;
      when 26=>trained<='1'; reload_latch:='0'; fsm:=8;

      ----------------------------------
      -- Hopfield forget algorithm
      ----------------------------------
      --  for i:=1 to 2**N do
      --    for j:=1 to 2**N do
      --        if i<>j then
      --          if (Pattern[i]=1 and Pattern[j]=1) or
      --             (Pattern[i]=-1 and Pattern[j]=-1)
      --          then W[i,j]:=W[i,j]-1
      --          else W[i,j]:=W[i,j]+1;
      when 32=>trained<='0'; reload_latch:='1'; 
               if cnt=2**18 then fsm:=33; else cnt:=cnt+1; end if;
      when 33=>W_rd_addr<=(others => '0');
               W_wr_addr<=(others => '0');
               fsm:=34;
      when 34=>if W_rd_addr(N-1 downto 0) = W_rd_addr(2*N-1 downto N)
               then fsm:=41; else fsm:=35;
               end if;
      when 35=>data_addr<=W_rd_addr(2*N-1 downto N); fsm:=36;
      when 36=>if conv_integer("0"&data_rd_value)<128 then pattern_i:=-1; else pattern_i:=1; end if;
               fsm:=37;
      when 37=>data_addr<=W_rd_addr(N-1 downto 0); fsm:=38;
      when 38=>if conv_integer("0"&data_rd_value)<128 then pattern_j:=-1; else pattern_i:=1; end if;
               fsm:=39;
      when 39=>if ((pattern_i=1)and(pattern_j=1))or((pattern_i=-1)and(pattern_j=-1))
               then W_wr_value<=W_rd_value-1;
               else W_wr_value<=W_rd_value+1;
               end if;
               w_cwr<='1'; fsm:=40;
      when 40=>w_cwr<='0'; fsm:=41;
      when 41=>if W_rd_addr=(2*N-1 downto 0 =>'1')
               then fsm:=42;
               else W_rd_addr<=W_rd_addr+1; W_wr_addr<=W_wr_addr+1; fsm:=34;
               end if;
      when 42=>trained<='1'; reload_latch:='0'; fsm:=8;
   when others => NULL;
   end case;
end if;
end process;
end;
