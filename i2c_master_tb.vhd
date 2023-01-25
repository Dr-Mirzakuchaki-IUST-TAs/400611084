library ieee;
use ieee.std_logic_1164.all;

entity i2c_master_tb is
end i2c_master_tb;

architecture behavioral of i2c_master_tb is

    component i2c_master is

        port(

            clk         :   in      std_logic;
            reset_n     :   in      std_logic;                      -- active-low async reset
            ena         :   in      std_logic;                      -- enable
            addr        :   in      std_logic_vector (6 downto 0);  -- slave address
            rw          :   in      std_logic;                      -- read/write bit
            data_wr     :   in      std_logic_vector (7 downto 0);  -- data sending to slave

            data_rd     :   out     std_logic_vector (7 downto 0);  -- data received form slave
            busy        :   out     std_logic;
            ack_err     :   buffer  std_logic;
        
            scl         :   inout   std_logic;                      -- i2c protocol lines
            sda         :   inout   std_logic

        );

    end component;

    signal clk         :         std_logic  :=  '0';
    signal    reset_n     :        std_logic;                      -- active-low async reset
    signal    ena         :        std_logic;                      -- enable
    signal    addr        :        std_logic_vector (6 downto 0);  -- slave address
    signal    rw          :        std_logic;                      -- read/write bit
    signal    data_wr     :        std_logic_vector (7 downto 0);  -- data sending to slave

    signal    data_rd     :       std_logic_vector (7 downto 0);  -- data received form slave
    signal    busy        :       std_logic;
    signal    ack_err     :     std_logic;
        
    signal    scl         :     std_logic;                      -- i2c protocol lines
    signal    sda         :     std_logic;

begin

    dut: i2c_master

        port map (

        clk =>  clk,
        reset_n =>  reset_n,
        ena =>  ena,
        addr   =>   addr,
        rw  => rw,
        data_wr =>  data_wr,
        data_rd =>  data_rd,
        busy    =>  busy,
        ack_err =>  ack_err,
        scl     =>      scl,
        sda =>  sda
        );

    clk <= not clk after 10 ns; -- clk freq: 50 Mhz

    reset_n <= '0', '1' after 100 ns;
    ena <=  '0', '1' after 12590 ns, '0' after 32590 ns;
    addr <= "1010101";
    rw  <=  '0';
    data_wr <=  "11111111";
    sda <=  'Z', '0' after 102750 ns, 'Z' after 112770 ns, '0' after 192930 ns, 'Z' after 202970 ns;

end behavioral;